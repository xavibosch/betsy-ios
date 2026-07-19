import Foundation

final class RealSportsDataProvider: SportsDataProvider {
    let mode: SportsDataMode = .real

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        config.waitsForConnectivity = false
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 50 * 1024 * 1024)
        return URLSession(configuration: config)
    }()

    private var oddsTasks: [URLSessionDataTask] = []
    private var liveTask: URLSessionDataTask?
    private var scoreTasks: [URLSessionDataTask] = []

    // Keys live in APISecrets.swift (gitignored). TODO: move to server-side proxy.
    private let oddsApiKey  = APISecrets.oddsApiKey
    private let rapidApiKey = APISecrets.rapidApiKey

    private let sportKeyToDisplay: [String: String] = [
        "basketball_nba": "NBA",
        "soccer_spain_la_liga": "LaLiga",
        "soccer_spain_copa_del_rey": "Copa del Rey",
        "soccer_epl": "Premier",
        "soccer_england_fa_cup": "FA Cup",
        "soccer_england_efl_cup": "EFL Cup",
        "soccer_germany_bundesliga": "Bundesliga",
        "soccer_germany_dfb_pokal": "DFB Pokal",
        "soccer_italy_serie_a": "Serie A",
        "soccer_italy_coppa_italia": "Coppa Italia",
        "soccer_france_ligue_one": "Ligue 1",
        "soccer_france_coupe_de_france": "Coupe de France"
    ]

    private let leagueIDs: [String: String] = [
        "LaLiga": "140",
        "Premier": "39",
        "Serie A": "135",
        "Bundesliga": "78",
        "Ligue 1": "61"
    ]

    private lazy var isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private lazy var isoFormatterNoFrac: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    deinit {
        cancelScoreRequests()
        cancelOddsRequests()
        cancelLiveRequest()
    }

    func cancelOddsRequests() {
        oddsTasks.forEach { $0.cancel() }
        oddsTasks.removeAll()
    }

    func cancelLiveRequest() {
        liveTask?.cancel()
        liveTask = nil
    }

    func cancelScoreRequests() {
        scoreTasks.forEach { $0.cancel() }
        scoreTasks.removeAll()
    }

    func fetchOdds(
        for sport: String,
        completion: @escaping (Result<[Match], SportsDataProviderError>) -> Void
    ) {
        fetchOddsForSport(sport, completion: completion)
    }

    func fetchScores(
        for sport: String,
        completion: @escaping ([String: MatchScore]) -> Void
    ) {
        let urlString = "https://api.the-odds-api.com/v4/sports/\(sport)/scores/?apiKey=\(oddsApiKey)&daysFrom=3"
        guard let url = URL(string: urlString) else {
            completion([:])
            return
        }

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        let task = session.dataTask(with: request) { [weak self] data, response, _ in
            guard let self else { return }
            guard let data else {
                completion([:])
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                completion([:])
                return
            }
            do {
                let decoded = try JSONDecoder().decode([RealScoreResponse].self, from: data)
                var result: [String: MatchScore] = [:]
                for item in decoded {
                    guard let eventId = item.id else { continue }
                    let homeScore = item.score(for: item.home_team)
                    let awayScore = item.score(for: item.away_team)
                    guard homeScore != nil || awayScore != nil || item.completed == true else { continue }
                    let lastUpdate = parseCommenceTime(item.last_update)
                    result[eventId] = MatchScore(
                        eventId: eventId,
                        home: item.home_team,
                        away: item.away_team,
                        homeScore: homeScore,
                        awayScore: awayScore,
                        completed: item.completed ?? false,
                        lastUpdate: lastUpdate
                    )
                }
                completion(result)
            } catch {
                completion([:])
            }
        }
        scoreTasks.append(task)
        task.resume()
    }

    func fetchLiveMatches(
        leagueName: String,
        completion: @escaping (Result<[RapidMatch], SportsDataProviderError>) -> Void
    ) {
        guard let leagueId = leagueIDs[leagueName] else {
            completion(.failure(SportsDataProviderError(message: "Liga no soportada.")))
            return
        }

        let urlString = "https://free-api-live-football-data.p.rapidapi.com/football-get-matches-by-league?leagueid=\(leagueId)"
        guard let url = URL(string: urlString) else {
            completion(.failure(SportsDataProviderError(message: "URL de en vivo invalida.")))
            return
        }

        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8)
        request.addValue(rapidApiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.addValue("free-api-live-football-data.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")

        liveTask = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let urlError = error as? URLError, urlError.code == .cancelled {
                return
            }

            if let error {
                completion(.failure(SportsDataProviderError(message: friendlyError(error))))
                return
            }

            guard let data else {
                completion(.failure(SportsDataProviderError(message: "No hay datos en vivo.")))
                return
            }

            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                completion(.failure(SportsDataProviderError(message: httpError(http.statusCode))))
                return
            }

            Task { @MainActor in
                do {
                    let result = try JSONDecoder().decode(RapidLiveResponse.self, from: data)
                    completion(.success(result.response))
                } catch {
                    completion(.failure(SportsDataProviderError(message: "Error al leer en vivo.")))
                }
            }
        }
        liveTask?.resume()
    }

    func debugLeagues() {
#if DEBUG
        let url = URL(string: "https://free-api-live-football-data.p.rapidapi.com/football-get-all-leagues")!
        var request = URLRequest(url: url)
        request.addValue(rapidApiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.addValue("free-api-live-football-data.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data, let str = String(data: data, encoding: .utf8) {
                print("📋 LIGAS DISPONIBLES:\n\(str)")
            }
        }.resume()
#endif
    }

    private func friendlyError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "Sin conexión a internet."
            case .timedOut:
                return "La conexión tardó demasiado."
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "No se pudo conectar al servidor."
            case .networkConnectionLost:
                return "Se perdió la conexión."
            default:
                return "No se pudo cargar."
            }
        }
        return "No se pudo cargar."
    }

    private func httpError(_ status: Int) -> String {
        switch status {
        case 401, 403:
            return "API key inválida o sin permisos."
        case 404:
            return "Endpoint no encontrado."
        case 429:
            return "Límite de requests alcanzado."
        default:
            return "Error del servidor (\(status))."
        }
    }

    private func regionForSport(_ sport: String) -> String {
        if sport.hasPrefix("basketball_") { return "us" }
        return "eu"
    }

    private func parseCommenceTime(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let date = isoFormatter.date(from: value) { return date }
        return isoFormatterNoFrac.date(from: value)
    }

    private func marketsForSport(_ sport: String) -> [String] {
        if sport == "basketball_nba" {
            return [
                "h2h",
                "spreads",
                "totals",
                "alternate_spreads",
                "alternate_totals",
                "team_totals",
                "h2h_q1",
                "h2h_q2",
                "h2h_q3",
                "h2h_q4",
                "spreads_q1",
                "spreads_q2",
                "spreads_q3",
                "spreads_q4",
                "totals_q1",
                "totals_q2",
                "totals_q3",
                "totals_q4"
            ]
        }
        return [
            "h2h",
            "spreads",
            "totals",
            "alternate_spreads",
            "alternate_totals",
            "team_totals",
            "draw_no_bet",
            "double_chance",
            "both_teams_to_score"
        ]
    }

    private func marketDisplayName(_ key: String) -> String {
        let map: [String: String] = [
            "h2h": "Ganador",
            "spreads": "Hándicap",
            "totals": "Total puntos/goles",
            "alternate_spreads": "Hándicap alternativo",
            "alternate_totals": "Totales alternativos",
            "team_totals": "Totales por equipo",
            "draw_no_bet": "Empate no apuesta",
            "double_chance": "Doble oportunidad",
            "both_teams_to_score": "Ambos marcan",
            "h2h_q1": "Ganador 1er cuarto",
            "h2h_q2": "Ganador 2º cuarto",
            "h2h_q3": "Ganador 3er cuarto",
            "h2h_q4": "Ganador 4º cuarto",
            "spreads_q1": "Hándicap 1er cuarto",
            "spreads_q2": "Hándicap 2º cuarto",
            "spreads_q3": "Hándicap 3er cuarto",
            "spreads_q4": "Hándicap 4º cuarto",
            "totals_q1": "Totales 1er cuarto",
            "totals_q2": "Totales 2º cuarto",
            "totals_q3": "Totales 3er cuarto",
            "totals_q4": "Totales 4º cuarto"
        ]
        return map[key] ?? key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func normalizedOutcomeLabel(name: String, home: String, away: String, marketKey: String) -> String {
        guard marketKey == "h2h" else { return name }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean == home.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() { return "1" }
        if clean == away.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() { return "2" }
        if ["draw", "empate", "x", "tie"].contains(clean) { return "X" }
        return name
    }

    private func fetchOddsForSport(
        _ sport: String,
        markets: [String]? = nil,
        completion: @escaping (Result<[Match], SportsDataProviderError>) -> Void
    ) {
        let region = regionForSport(sport)
        let marketList = markets ?? marketsForSport(sport)
        let marketsQuery = marketList.joined(separator: ",")
        let urlString = "https://api.the-odds-api.com/v4/sports/\(sport)/odds/?apiKey=\(oddsApiKey)&regions=\(region)&markets=\(marketsQuery)"
        guard let url = URL(string: urlString) else {
            completion(.failure(SportsDataProviderError(message: "URL de cuotas invalida.")))
            return
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let urlError = error as? URLError, urlError.code == .cancelled {
                completion(.failure(SportsDataProviderError(message: "Cancelado")))
                return
            }

            if let error {
                completion(.failure(SportsDataProviderError(message: friendlyError(error))))
                return
            }

            guard let data else {
                completion(.failure(SportsDataProviderError(message: "No hay datos de cuotas.")))
                return
            }

            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                if marketList != ["h2h"] {
                    fetchOddsForSport(sport, markets: ["h2h"], completion: completion)
                    return
                }
                completion(.failure(SportsDataProviderError(message: httpError(http.statusCode))))
                return
            }

            do {
                let decodedResponse = try JSONDecoder().decode([RealAPIResponse].self, from: data)
                let leagueTitle = sportKeyToDisplay[sport] ?? decodedResponse.first?.sport_title ?? sport
                let mapped = decodedResponse.map { item -> Match in
                    let firstBookie = item.bookmakers.first
                    let markets = firstBookie?.markets.compactMap { market -> BetMarket? in
                        let marketKey = market.key ?? "market"
                        let marketName = self.marketDisplayName(marketKey)
                        let outcomes = market.outcomes.map { outcome in
                            Odd(
                                label: self.normalizedOutcomeLabel(
                                    name: outcome.name,
                                    home: item.home_team,
                                    away: item.away_team,
                                    marketKey: marketKey
                                ),
                                value: outcome.price,
                                marketKey: marketKey,
                                marketName: marketName,
                                point: outcome.point
                            )
                        }
                        guard !outcomes.isEmpty else { return nil }
                        return BetMarket(
                            key: marketKey,
                            name: marketName,
                            outcomes: outcomes
                        )
                    } ?? []

                    let h2hOdds = markets.first(where: { $0.key == "h2h" })?.outcomes ?? []
                    let mainOdds = !h2hOdds.isEmpty ? h2hOdds : (markets.first?.outcomes ?? [])
                    let startDate = self.parseCommenceTime(item.commence_time)
                    return Match(
                        eventId: item.id,
                        sportKey: sport,
                        home: item.home_team,
                        away: item.away_team,
                        league: leagueTitle,
                        odds: mainOdds,
                        startDate: startDate,
                        markets: markets
                    )
                }
                completion(.success(mapped))
            } catch {
                if marketList != ["h2h"] {
                    fetchOddsForSport(sport, markets: ["h2h"], completion: completion)
                    return
                }
                completion(.failure(SportsDataProviderError(message: "Error al leer cuotas.")))
            }
        }
        oddsTasks.append(task)
        task.resume()
    }
}
