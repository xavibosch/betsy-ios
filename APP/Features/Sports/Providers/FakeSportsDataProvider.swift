import Foundation

final class FakeSportsDataProvider: SportsDataProvider {
    let mode: SportsDataMode = .fake
    private var simulationSettings: SportsSimulationSettings
    private let calendar: Calendar
    private let lock = NSLock()
    private var fixturesByKey: [String: [FakeFixture]] = [:]
    private let isoFormatter = ISO8601DateFormatter()

    init(simulationSettings: SportsSimulationSettings = .default) {
        self.simulationSettings = simulationSettings
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        self.calendar = calendar
    }

    func cancelOddsRequests() { }

    func cancelLiveRequest() { }

    func cancelScoreRequests() { }

    func fetchOdds(
        for sport: String,
        completion: @escaping (Result<[Match], SportsDataProviderError>) -> Void
    ) {
        let now = simulatedNow()
        let matches = fixtures(for: sport)
            .filter { status(for: $0, at: now) != .finished }
            .map { fixture in
                Match(
                    eventId: fixture.eventId,
                    sportKey: fixture.sportKey,
                    home: fixture.homeTeam,
                    away: fixture.awayTeam,
                    league: fixture.leagueName,
                    odds: fixture.odds,
                    startDate: fixture.startDate,
                    markets: fixture.markets
                )
            }
        completion(.success(matches))
    }

    func fetchScores(
        for sport: String,
        completion: @escaping ([String: MatchScore]) -> Void
    ) {
        let now = simulatedNow()
        var result: [String: MatchScore] = [:]

        for fixture in fixtures(for: sport) {
            let snapshot = liveSnapshot(for: fixture, at: now)
            guard snapshot.status != .scheduled else { continue }
            result[fixture.eventId] = MatchScore(
                eventId: fixture.eventId,
                home: fixture.homeTeam,
                away: fixture.awayTeam,
                homeScore: snapshot.homeScore,
                awayScore: snapshot.awayScore,
                completed: snapshot.status == .finished,
                lastUpdate: snapshot.lastUpdated
            )
        }

        completion(result)
    }

    func fetchLiveMatches(
        leagueName: String,
        completion: @escaping (Result<[RapidMatch], SportsDataProviderError>) -> Void
    ) {
        let sportKeys = leagueProfiles.values
            .filter { $0.displayName == leagueName && $0.supportsLiveMatches }
            .map(\.sportKey)

        guard !sportKeys.isEmpty else {
            completion(.failure(SportsDataProviderError(message: "Liga no soportada.")))
            return
        }

        let now = simulatedNow()
        let liveMatches = sportKeys
            .flatMap { fixtures(for: $0) }
            .compactMap { fixture -> RapidMatch? in
                let snapshot = liveSnapshot(for: fixture, at: now)
                guard snapshot.status == .live else { return nil }
                return makeRapidMatch(from: snapshot, fixture: fixture)
            }
            .sorted { $0.fixture.date < $1.fixture.date }

        completion(.success(liveMatches))
    }

    func debugLeagues() {
        let leagues = Set(leagueProfiles.values.filter(\.supportsLiveMatches).map(\.displayName)).sorted()
        print("FAKE SPORTS LEAGUES: \(leagues)")
    }

    func updateSimulationSettings(_ settings: SportsSimulationSettings) {
        lock.lock()
        simulationSettings = settings
        fixturesByKey.removeAll()
        lock.unlock()
    }
}

private extension FakeSportsDataProvider {
    struct LeagueProfile {
        let sportKey: String
        let displayName: String
        let country: String
        let teams: [String]
        let durationMinutes: Int
        let supportsLiveMatches: Bool
    }

    struct FakeFixture {
        let eventId: String
        let sportKey: String
        let leagueName: String
        let country: String
        let homeTeam: String
        let awayTeam: String
        let startDate: Date
        let durationMinutes: Int
        let odds: [Odd]
        let markets: [BetMarket]
        let finalHomeScore: Int
        let finalAwayScore: Int
    }

    struct SeededGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            self.state = seed == 0 ? 0x123456789ABCDEF : seed
        }

        mutating func nextUInt64() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }

        mutating func nextDouble() -> Double {
            Double(nextUInt64() % 10_000_000) / 10_000_000
        }

        mutating func nextInt(upperBound: Int) -> Int {
            guard upperBound > 0 else { return 0 }
            return Int(nextUInt64() % UInt64(upperBound))
        }

        mutating func nextInt(in range: ClosedRange<Int>) -> Int {
            let width = max(1, range.upperBound - range.lowerBound + 1)
            return range.lowerBound + nextInt(upperBound: width)
        }

        mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
            range.lowerBound + (range.upperBound - range.lowerBound) * nextDouble()
        }

        mutating func shuffle<T>(_ array: inout [T]) {
            guard array.count > 1 else { return }
            for index in stride(from: array.count - 1, through: 1, by: -1) {
                let swapIndex = nextInt(upperBound: index + 1)
                if swapIndex != index {
                    array.swapAt(index, swapIndex)
                }
            }
        }
    }

    var leagueProfiles: [String: LeagueProfile] {
        [
            "basketball_nba": LeagueProfile(
                sportKey: "basketball_nba",
                displayName: "NBA",
                country: "USA",
                teams: [
                    "Boston Celtics", "Milwaukee Bucks", "New York Knicks", "Miami Heat",
                    "Philadelphia 76ers", "Cleveland Cavaliers", "Denver Nuggets", "Minnesota Timberwolves",
                    "Oklahoma City Thunder", "Dallas Mavericks", "Phoenix Suns", "Golden State Warriors",
                    "Los Angeles Lakers", "Sacramento Kings", "New Orleans Pelicans", "Orlando Magic",
                    "Indiana Pacers", "Memphis Grizzlies", "Los Angeles Clippers", "Houston Rockets"
                ],
                durationMinutes: 150,
                supportsLiveMatches: false
            ),
            "soccer_spain_la_liga": LeagueProfile(
                sportKey: "soccer_spain_la_liga",
                displayName: "LaLiga",
                country: "Spain",
                teams: [
                    "Real Madrid", "Barcelona", "Atletico Madrid", "Girona",
                    "Athletic Club", "Real Sociedad", "Real Betis", "Sevilla",
                    "Valencia", "Villarreal", "Getafe", "Osasuna",
                    "Celta Vigo", "Mallorca", "Rayo Vallecano", "Las Palmas",
                    "Alaves", "Cadiz", "Granada", "Espanyol"
                ],
                durationMinutes: 105,
                supportsLiveMatches: true
            ),
            "soccer_spain_copa_del_rey": LeagueProfile(
                sportKey: "soccer_spain_copa_del_rey",
                displayName: "Copa del Rey",
                country: "Spain",
                teams: [
                    "Barcelona", "Real Madrid", "Atletico Madrid", "Athletic Club",
                    "Sevilla", "Villarreal", "Real Betis", "Real Sociedad",
                    "Valencia", "Osasuna", "Getafe", "Mallorca",
                    "Celta Vigo", "Alaves", "Girona", "Las Palmas"
                ],
                durationMinutes: 105,
                supportsLiveMatches: false
            ),
            "soccer_epl": LeagueProfile(
                sportKey: "soccer_epl",
                displayName: "Premier",
                country: "England",
                teams: [
                    "Manchester City", "Arsenal", "Liverpool", "Tottenham",
                    "Aston Villa", "Chelsea", "Manchester United", "Newcastle",
                    "Brighton", "West Ham", "Brentford", "Crystal Palace",
                    "Fulham", "Wolves", "Everton", "Bournemouth",
                    "Burnley", "Nottingham Forest", "Leicester City", "Southampton"
                ],
                durationMinutes: 105,
                supportsLiveMatches: true
            ),
            "soccer_england_fa_cup": LeagueProfile(
                sportKey: "soccer_england_fa_cup",
                displayName: "FA Cup",
                country: "England",
                teams: [
                    "Arsenal", "Liverpool", "Chelsea", "Manchester United",
                    "Manchester City", "Tottenham", "Everton", "Aston Villa",
                    "Leeds United", "Leicester City", "West Ham", "Newcastle",
                    "Brighton", "Fulham", "Brentford", "Wolves"
                ],
                durationMinutes: 105,
                supportsLiveMatches: false
            ),
            "soccer_england_efl_cup": LeagueProfile(
                sportKey: "soccer_england_efl_cup",
                displayName: "EFL Cup",
                country: "England",
                teams: [
                    "Chelsea", "Liverpool", "Arsenal", "Tottenham",
                    "Aston Villa", "Newcastle", "West Ham", "Brentford",
                    "Fulham", "Bournemouth", "Wolves", "Crystal Palace",
                    "Leeds United", "Leicester City", "Burnley", "Southampton"
                ],
                durationMinutes: 105,
                supportsLiveMatches: false
            ),
            "soccer_germany_bundesliga": LeagueProfile(
                sportKey: "soccer_germany_bundesliga",
                displayName: "Bundesliga",
                country: "Germany",
                teams: [
                    "Bayern Munich", "Borussia Dortmund", "RB Leipzig", "Bayer Leverkusen",
                    "Stuttgart", "Eintracht Frankfurt", "Freiburg", "Wolfsburg",
                    "Hoffenheim", "Union Berlin", "Werder Bremen", "Augsburg",
                    "Mainz", "Monchengladbach", "Heidenheim", "Bochum",
                    "Koln", "Hamburg", "St. Pauli", "Darmstadt"
                ],
                durationMinutes: 105,
                supportsLiveMatches: true
            ),
            "soccer_germany_dfb_pokal": LeagueProfile(
                sportKey: "soccer_germany_dfb_pokal",
                displayName: "DFB Pokal",
                country: "Germany",
                teams: [
                    "Bayern Munich", "Borussia Dortmund", "RB Leipzig", "Bayer Leverkusen",
                    "Eintracht Frankfurt", "Freiburg", "Wolfsburg", "Union Berlin",
                    "Hoffenheim", "Mainz", "Koln", "Stuttgart",
                    "Hamburg", "St. Pauli", "Bochum", "Augsburg"
                ],
                durationMinutes: 105,
                supportsLiveMatches: false
            ),
            "soccer_italy_serie_a": LeagueProfile(
                sportKey: "soccer_italy_serie_a",
                displayName: "Serie A",
                country: "Italy",
                teams: [
                    "Inter", "AC Milan", "Juventus", "Napoli",
                    "Roma", "Lazio", "Atalanta", "Bologna",
                    "Fiorentina", "Torino", "Monza", "Genoa",
                    "Udinese", "Sassuolo", "Lecce", "Cagliari",
                    "Verona", "Empoli", "Parma", "Como"
                ],
                durationMinutes: 105,
                supportsLiveMatches: true
            ),
            "soccer_italy_coppa_italia": LeagueProfile(
                sportKey: "soccer_italy_coppa_italia",
                displayName: "Coppa Italia",
                country: "Italy",
                teams: [
                    "Inter", "AC Milan", "Juventus", "Napoli",
                    "Roma", "Lazio", "Atalanta", "Fiorentina",
                    "Torino", "Bologna", "Udinese", "Monza",
                    "Genoa", "Lecce", "Cagliari", "Empoli"
                ],
                durationMinutes: 105,
                supportsLiveMatches: false
            ),
            "soccer_france_ligue_one": LeagueProfile(
                sportKey: "soccer_france_ligue_one",
                displayName: "Ligue 1",
                country: "France",
                teams: [
                    "PSG", "Monaco", "Marseille", "Lille",
                    "Lyon", "Nice", "Lens", "Rennes",
                    "Strasbourg", "Brest", "Toulouse", "Montpellier",
                    "Nantes", "Reims", "Le Havre", "Metz",
                    "Auxerre", "Angers", "Saint-Etienne", "Lorient"
                ],
                durationMinutes: 105,
                supportsLiveMatches: true
            ),
            "soccer_france_coupe_de_france": LeagueProfile(
                sportKey: "soccer_france_coupe_de_france",
                displayName: "Coupe de France",
                country: "France",
                teams: [
                    "PSG", "Marseille", "Monaco", "Lille",
                    "Lyon", "Nice", "Lens", "Rennes",
                    "Strasbourg", "Brest", "Toulouse", "Montpellier",
                    "Nantes", "Reims", "Le Havre", "Saint-Etienne"
                ],
                durationMinutes: 105,
                supportsLiveMatches: false
            )
        ]
    }

    func fixtures(for sport: String) -> [FakeFixture] {
        let dayStart = calendar.startOfDay(for: DevSimulationClock.now())
        let cacheKey = "\(sport)|\(dayKey(for: dayStart))"

        lock.lock()
        if let cached = fixturesByKey[cacheKey] {
            lock.unlock()
            return cached
        }

        let generated = generateFixtures(for: sport, dayStart: dayStart)
        fixturesByKey[cacheKey] = generated
        lock.unlock()
        return generated
    }

    func generateFixtures(for sport: String, dayStart: Date) -> [FakeFixture] {
        let profile = leagueProfiles[sport] ?? fallbackProfile(for: sport)
        let count = max(10, min(12, profile.teams.count / 2))
        var generator = SeededGenerator(seed: seed(for: sport, dayStart: dayStart))
        var teams = profile.teams
        generator.shuffle(&teams)

        let scheduleStartMinutes = sport == "basketball_nba" ? 12 * 60 : 10 * 60
        let scheduleEndMinutes = sport == "basketball_nba" ? 23 * 60 : 22 * 60
        let step = max(45, (scheduleEndMinutes - scheduleStartMinutes) / max(1, count - 1))
        var fixtures: [FakeFixture] = []

        for index in 0..<count {
            let homeIndex = (index * 2) % teams.count
            let awayIndex = (homeIndex + 1 + generator.nextInt(upperBound: max(1, teams.count - 1))) % teams.count
            let homeTeam = teams[homeIndex]
            var awayTeam = teams[awayIndex]
            if awayTeam == homeTeam {
                awayTeam = teams[(awayIndex + 1) % teams.count]
            }

            let baseMinutes = scheduleStartMinutes + (index * step)
            let jitter = generator.nextInt(in: -18...18)
            let kickoffMinutes = max(0, min((23 * 60) + 30, baseMinutes + jitter))
            let startDate = calendar.date(byAdding: .minute, value: kickoffMinutes, to: dayStart) ?? dayStart
            let eventId = "fake_\(dayKey(for: dayStart))_\(sport)_\(index)_\(stableHash("\(homeTeam)|\(awayTeam)") % 10_000)"
            let homeStrength = teamStrength(for: homeTeam)
            let awayStrength = teamStrength(for: awayTeam)
            let moneylineOdds = makeMoneylineOdds(
                sport: sport,
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                homeStrength: homeStrength,
                awayStrength: awayStrength
            )
            let scoreline = makeFinalScore(
                sport: sport,
                homeStrength: homeStrength,
                awayStrength: awayStrength,
                generator: &generator
            )

            let mainMarket = BetMarket(key: "h2h", name: "Ganador", outcomes: moneylineOdds)
            fixtures.append(
                FakeFixture(
                    eventId: eventId,
                    sportKey: sport,
                    leagueName: profile.displayName,
                    country: profile.country,
                    homeTeam: homeTeam,
                    awayTeam: awayTeam,
                    startDate: startDate,
                    durationMinutes: profile.durationMinutes,
                    odds: moneylineOdds,
                    markets: [mainMarket],
                    finalHomeScore: scoreline.home,
                    finalAwayScore: scoreline.away
                )
            )
        }

        return fixtures.sorted { $0.startDate < $1.startDate }
    }

    func fallbackProfile(for sport: String) -> LeagueProfile {
        LeagueProfile(
            sportKey: sport,
            displayName: sport.replacingOccurrences(of: "_", with: " ").capitalized,
            country: "Global",
            teams: [
                "Alpha FC", "Bravo United", "Capital City", "Dynamo Club",
                "Eastern Stars", "Forest Athletic", "Golden Lions", "Harbor SC",
                "Iron Town", "Jade Rovers", "Kingston", "Liberty FC",
                "Metro Athletic", "Northside", "Olympic SC", "Royal Club",
                "Sporting Azul", "Union 04", "Victory FC", "West End"
            ],
            durationMinutes: sport == "basketball_nba" ? 150 : 105,
            supportsLiveMatches: false
        )
    }

    func seed(for sport: String, dayStart: Date) -> UInt64 {
        let dateSeed = UInt64(dayKey(for: dayStart)) ?? 0
        let settingsSeed = UInt64(max(1, simulationSettings.seed))
        return settingsSeed ^ stableHash(sport) ^ dateSeed
    }

    func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 2000
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d%02d%02d", year, month, day)
    }

    func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for scalar in value.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash &*= 1099511628211
        }
        return hash
    }

    func teamStrength(for team: String) -> Int {
        72 + Int(stableHash(team) % 20)
    }

    func makeMoneylineOdds(
        sport: String,
        homeTeam: String,
        awayTeam: String,
        homeStrength: Int,
        awayStrength: Int
    ) -> [Odd] {
        let gap = Double(homeStrength - awayStrength) / 20.0
        let homeProbBase = max(0.18, 0.46 + (gap * 0.16) + 0.06)
        let awayProbBase = max(0.14, 0.34 - (gap * 0.16))

        if sport == "basketball_nba" {
            let total = homeProbBase + awayProbBase
            let homeProb = homeProbBase / total
            let awayProb = awayProbBase / total
            return [
                Odd(label: "1", value: decimalOdds(forProbability: homeProb, minimum: 1.35, maximum: 3.4), marketKey: "h2h", marketName: "Ganador"),
                Odd(label: "2", value: decimalOdds(forProbability: awayProb, minimum: 1.35, maximum: 3.6), marketKey: "h2h", marketName: "Ganador")
            ]
        }

        let drawProbBase = max(0.18, 0.26 - min(0.08, abs(gap) * 0.05))
        let total = homeProbBase + awayProbBase + drawProbBase
        let homeProb = homeProbBase / total
        let drawProb = drawProbBase / total
        let awayProb = awayProbBase / total

        return [
            Odd(label: "1", value: decimalOdds(forProbability: homeProb, minimum: 1.45, maximum: 3.5), marketKey: "h2h", marketName: "Ganador"),
            Odd(label: "X", value: decimalOdds(forProbability: drawProb, minimum: 2.4, maximum: 3.5), marketKey: "h2h", marketName: "Ganador"),
            Odd(label: "2", value: decimalOdds(forProbability: awayProb, minimum: 1.55, maximum: 3.8), marketKey: "h2h", marketName: "Ganador")
        ]
    }

    func decimalOdds(forProbability probability: Double, minimum: Double, maximum: Double) -> Double {
        let safeProbability = Swift.max(0.12, Swift.min(0.78, probability))
        let raw = (1 / safeProbability) * 0.94
        let bounded = Swift.max(minimum, Swift.min(maximum, raw))
        return (bounded * 100).rounded() / 100
    }

    func makeFinalScore(
        sport: String,
        homeStrength: Int,
        awayStrength: Int,
        generator: inout SeededGenerator
    ) -> (home: Int, away: Int) {
        let gap = Double(homeStrength - awayStrength) / 10.0

        if sport == "basketball_nba" {
            let homeBase = 103 + Int(gap * 3) + generator.nextInt(in: -8...10)
            let awayBase = 100 - Int(gap * 2) + generator.nextInt(in: -8...10)
            return (
                home: max(88, min(132, homeBase)),
                away: max(84, min(128, awayBase))
            )
        }

        let homeExpected = 1.2 + (gap * 0.18) + 0.25 + generator.nextDouble(in: -0.35...0.45)
        let awayExpected = 1.05 - (gap * 0.15) + generator.nextDouble(in: -0.35...0.35)
        return (
            home: goals(fromExpected: homeExpected),
            away: goals(fromExpected: awayExpected)
        )
    }

    func goals(fromExpected expected: Double) -> Int {
        switch expected {
        case ..<0.55:
            return 0
        case ..<1.15:
            return 1
        case ..<1.85:
            return 2
        case ..<2.55:
            return 3
        case ..<3.25:
            return 4
        default:
            return 5
        }
    }

    func simulatedNow() -> Date {
        let now = DevSimulationClock.now()
        guard simulationSettings.accelerationMultiplier > 1 else { return now }
        let dayStart = calendar.startOfDay(for: now)
        let elapsed = now.timeIntervalSince(dayStart)
        return dayStart.addingTimeInterval(elapsed * simulationSettings.accelerationMultiplier)
    }

    func status(for fixture: FakeFixture, at now: Date) -> FixtureStatus {
        if now < fixture.startDate {
            return .scheduled
        }
        let finishedAt = fixture.startDate.addingTimeInterval(TimeInterval(fixture.durationMinutes * 60))
        if now >= finishedAt {
            return .finished
        }
        return .live
    }

    func liveSnapshot(for fixture: FakeFixture, at now: Date) -> LiveMatchSnapshot {
        let status = status(for: fixture, at: now)
        let elapsed = max(0, Int(now.timeIntervalSince(fixture.startDate) / 60))
        let progress = min(1, max(0, Double(elapsed) / Double(max(1, fixture.durationMinutes))))

        let homeScore: Int?
        let awayScore: Int?

        switch status {
        case .scheduled:
            homeScore = nil
            awayScore = nil
        case .finished:
            homeScore = fixture.finalHomeScore
            awayScore = fixture.finalAwayScore
        case .live:
            homeScore = projectedLiveScore(finalScore: fixture.finalHomeScore, progress: progress)
            awayScore = projectedLiveScore(finalScore: fixture.finalAwayScore, progress: progress)
        }

        return LiveMatchSnapshot(
            id: fixture.eventId,
            eventId: fixture.eventId,
            sportKey: fixture.sportKey,
            leagueName: fixture.leagueName,
            homeTeam: fixture.homeTeam,
            awayTeam: fixture.awayTeam,
            homeScore: homeScore,
            awayScore: awayScore,
            status: status,
            elapsed: status == .scheduled ? nil : min(fixture.durationMinutes, elapsed),
            lastUpdated: now
        )
    }

    func projectedLiveScore(finalScore: Int, progress: Double) -> Int {
        guard finalScore > 0 else { return 0 }
        let thresholds: [Double]
        switch finalScore {
        case 1:
            thresholds = [0.52]
        case 2:
            thresholds = [0.28, 0.74]
        case 3:
            thresholds = [0.18, 0.48, 0.81]
        case 4:
            thresholds = [0.14, 0.37, 0.63, 0.88]
        default:
            thresholds = [0.11, 0.28, 0.45, 0.66, 0.84]
        }
        return thresholds.filter { progress >= $0 }.count
    }

    func makeRapidMatch(from snapshot: LiveMatchSnapshot, fixture: FakeFixture) -> RapidMatch {
        RapidMatch(
            fixture: RapidFixture(
                id: rapidId(for: fixture.eventId),
                date: isoFormatter.string(from: fixture.startDate),
                status: RapidStatus(short: snapshot.status == .finished ? "FT" : "LIVE", elapsed: snapshot.elapsed)
            ),
            teams: RapidTeams(
                home: RapidTeam(id: rapidId(for: fixture.homeTeam), name: fixture.homeTeam, logo: nil),
                away: RapidTeam(id: rapidId(for: fixture.awayTeam), name: fixture.awayTeam, logo: nil)
            ),
            goals: RapidGoals(home: snapshot.homeScore, away: snapshot.awayScore),
            league: RapidLeague(name: fixture.leagueName, country: fixture.country, logo: nil)
        )
    }

    func rapidId(for value: String) -> Int {
        let raw = stableHash(value) % UInt64(Int32.max)
        return max(1, Int(raw))
    }
}
