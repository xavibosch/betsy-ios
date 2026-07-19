import Foundation

struct LeagueTicketsStore: Codable {
    var byLeague: [String: [UserTicket]]
}

struct DailyBetsStore: Codable {
    var bets: [String: Int]
    var dates: [String: String]
}

enum TicketStore {
    private static let historyRetentionDays = 5
    private static let devHistoryRetentionDays = 3

    static func loadHistory(from data: Data) -> [String: [UserTicket]] {
        guard !data.isEmpty else { return [:] }
        if let decoded = try? JSONDecoder().decode(LeagueTicketsStore.self, from: data) {
            return prune(decoded.byLeague)
        }
        if let legacy = try? JSONDecoder().decode([UserTicket].self, from: data) {
            return prune(["global": legacy])
        }
        return [:]
    }

    static func saveHistory(_ value: [String: [UserTicket]]) -> Data {
        (try? JSONEncoder().encode(LeagueTicketsStore(byLeague: prune(value)))) ?? Data()
    }

    static func loadDailyBets(from data: Data) -> DailyBetsStore {
        guard !data.isEmpty else { return DailyBetsStore(bets: [:], dates: [:]) }
        return (try? JSONDecoder().decode(DailyBetsStore.self, from: data))
            ?? DailyBetsStore(bets: [:], dates: [:])
    }

    static func saveDailyBets(_ value: DailyBetsStore) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    private static func prune(_ value: [String: [UserTicket]]) -> [String: [UserTicket]] {
        let retention = UserDefaults.standard.bool(forKey: "isDevModeActive") ? devHistoryRetentionDays : historyRetentionDays
        let cutoff = DevSimulationClock.cutoffDate(retentionDays: retention)
        return value.mapValues { tickets in
            tickets.filter { $0.date > cutoff }
        }
        .filter { !$0.value.isEmpty }
    }
}
