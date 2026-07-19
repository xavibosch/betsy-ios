import Foundation
import Combine

final class APIManager: ObservableObject {
    @Published var matches: [Match] = []
    @Published var scoreByEventId: [String: MatchScore] = [:]
    @Published var liveMatches: [RapidMatch] = []

    @Published var isLoadingOdds: Bool = false
    @Published var isLoadingLive: Bool = false
    @Published var oddsError: String? = nil
    @Published var liveError: String? = nil

    private let repository: SportsDataRepository
    private var lastOddsFetch: [String: Date] = [:]
    private var lastLiveFetch: [String: Date] = [:]
    private var currentOddsSport: String?
    private var currentLiveLeague: String?
    private var currentScoreSports: [String] = []
    private let oddsTTL: TimeInterval = 60
    private let liveTTL: TimeInterval = 20
    private var matchesCache: [String: [Match]] = [:]
    private var liveCache: [String: [RapidMatch]] = [:]
    private var scoreTimer: Timer?

    private struct OddsFetchError: Error {
        let message: String
    }

    init(repository: SportsDataRepository = SportsDataRepository()) {
        self.repository = repository
    }

    deinit {
        scoreTimer?.invalidate()
        repository.cancelScoreRequests()
        repository.cancelOddsRequests()
        repository.cancelLiveRequest()
    }

    func updateScoreTracking(sports: [String]) {
        startScorePolling(sports: sports)
    }

    private func startScorePolling(sports: [String]) {
        let normalized = sports.sorted()
        guard !normalized.isEmpty else {
            scoreTimer?.invalidate()
            scoreTimer = nil
            currentScoreSports = []
            scoreByEventId = [:]
            repository.cancelScoreRequests()
            return
        }

        if normalized != currentScoreSports {
            currentScoreSports = normalized
            scoreTimer?.invalidate()
            scoreTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
                self?.fetchScoresMulti(sports: normalized)
            }
        }

        fetchScoresMulti(sports: normalized)
    }

    private func fetchScoresMulti(sports: [String]) {
        guard !sports.isEmpty else { return }
        repository.cancelScoreRequests()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "scores.merge.queue")
        var merged: [String: MatchScore] = [:]

        for sport in sports {
            group.enter()
            repository.fetchScores(for: sport) { scores in
                queue.sync {
                    for (eventId, score) in scores {
                        merged[eventId] = score
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if sports.sorted() == self.currentScoreSports {
                self.scoreByEventId = merged
            }
        }
    }

    func fetchRealOdds(sport: String, force: Bool = false) {
        fetchRealOddsMulti(keys: [sport], force: force)
    }

    func fetchRealOddsMulti(keys: [String], force: Bool = false) {
        let trimmed = keys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let unique = Array(Set(trimmed)).filter { !$0.isEmpty }
        guard !unique.isEmpty else { return }
        startScorePolling(sports: unique)

        let cacheKey = unique.sorted().joined(separator: "|")

        if !force,
           currentOddsSport == cacheKey,
           !matches.isEmpty,
           let last = lastOddsFetch[cacheKey],
           Date().timeIntervalSince(last) < oddsTTL {
            return
        }

        let isSameSport = currentOddsSport == cacheKey
        currentOddsSport = cacheKey
        if let cached = matchesCache[cacheKey], !cached.isEmpty {
            matches = cached
        } else if !isSameSport {
            matches = []
        }

        repository.cancelOddsRequests()
        isLoadingOdds = true
        oddsError = nil

        let group = DispatchGroup()
        let syncQueue = DispatchQueue(label: "odds.merge.queue")
        var allMatches: [Match] = []
        var errors: [String] = []

        for sport in unique {
            group.enter()
            repository.fetchOdds(for: sport) { result in
                syncQueue.sync {
                    switch result {
                    case .success(let matches):
                        allMatches.append(contentsOf: matches)
                    case .failure(let error):
                        errors.append(error.message)
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            guard self.currentOddsSport == cacheKey else { return }
            self.isLoadingOdds = false
            if allMatches.isEmpty {
                self.oddsError = errors.first ?? "No se pudo cargar."
                return
            }
            self.matches = allMatches
            self.matchesCache[cacheKey] = allMatches
            self.lastOddsFetch[cacheKey] = Date()
        }
    }

    func fetchLiveScores(leagueName: String, force: Bool = false) {
        if !force,
           currentLiveLeague == leagueName,
           !liveMatches.isEmpty,
           let last = lastLiveFetch[leagueName],
           Date().timeIntervalSince(last) < liveTTL {
            return
        }

        let isSameLeague = currentLiveLeague == leagueName
        currentLiveLeague = leagueName
        if let cached = liveCache[leagueName], !cached.isEmpty {
            liveMatches = cached
        } else if !isSameLeague {
            liveMatches = []
        }

        repository.cancelLiveRequest()
        isLoadingLive = true
        liveError = nil

        repository.fetchLiveMatches(leagueName: leagueName) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let liveMatches):
                    self.liveMatches = liveMatches
                    self.liveCache[leagueName] = liveMatches
                    self.isLoadingLive = false
                    self.liveError = nil
                    self.lastLiveFetch[leagueName] = Date()
                case .failure(let error):
                    self.isLoadingLive = false
                    self.liveError = error.message
                }
            }
        }
    }

    func debugLeagues() {
        repository.debugLeagues()
    }
}

struct RealAPIResponse: Codable {
    let id: String?
    let sport_key: String?
    let home_team: String
    let away_team: String
    let sport_title: String
    let bookmakers: [Bookmaker]
    let commence_time: String?
}

struct RealScoreResponse: Codable {
    let id: String?
    let home_team: String
    let away_team: String
    let completed: Bool?
    let scores: [APIScore]?
    let last_update: String?

    func score(for teamName: String) -> Int? {
        guard let scores else { return nil }
        let item = scores.first { $0.name.lowercased() == teamName.lowercased() }
        return item?.score
    }
}

struct Bookmaker: Codable {
    let markets: [APIMarket]
}

struct APIMarket: Codable {
    let key: String?
    let outcomes: [APIOutcome]
}

struct APIOutcome: Codable {
    let name: String
    let price: Double
    let point: Double?
}

struct APIScore: Codable {
    let name: String
    let score: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case score
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        if let intScore = try? container.decode(Int.self, forKey: .score) {
            score = intScore
        } else if let stringScore = try? container.decode(String.self, forKey: .score) {
            score = Int(stringScore)
        } else {
            score = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(score, forKey: .score)
    }
}

struct RapidLiveResponse: Codable, Sendable {
    let response: [RapidMatch]
}

struct RapidMatch: Codable, Identifiable, Sendable {
    var id: Int { fixture.id }
    let fixture: RapidFixture
    let teams: RapidTeams
    let goals: RapidGoals
    let league: RapidLeague
}

struct RapidFixture: Codable, Sendable {
    let id: Int
    let date: String
    let status: RapidStatus
}

struct RapidStatus: Codable, Sendable {
    let short: String
    let elapsed: Int?
}

struct RapidTeams: Codable, Sendable {
    let home: RapidTeam
    let away: RapidTeam
}

struct RapidTeam: Codable, Sendable {
    let id: Int
    let name: String
    let logo: String?
}

struct RapidGoals: Codable, Sendable {
    let home: Int?
    let away: Int?
}

struct RapidLeague: Codable, Sendable {
    let name: String
    let country: String
    let logo: String?
}

