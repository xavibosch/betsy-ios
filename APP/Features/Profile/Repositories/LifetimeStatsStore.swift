import Foundation

// Persistent lifetime stats — accumulate across all bets the user ever places.
// Stays stable as days advance and tickets are settled. Never decreases.
// Each ticket is processed exactly once via processedTicketIds + settledTicketIds.

struct LifetimeStats: Codable, Equatable {
    var totalBetCount: Int = 0
    var resolvedCount: Int = 0
    var wonCount: Int = 0
    var lostCount: Int = 0
    var totalStake: Int = 0
    var totalPayout: Int = 0
    var sumOddsValue: Double = 0
    var oddsCount: Int = 0
    var bestStreak: Int = 0
    var processedTicketIds: Set<UUID> = []
    var settledTicketIds: Set<UUID> = []

    var hitRate: Int {
        guard resolvedCount > 0 else { return 0 }
        return Int((Double(wonCount) / Double(resolvedCount) * 100).rounded())
    }

    var averageOdd: Double? {
        guard oddsCount > 0 else { return nil }
        return sumOddsValue / Double(oddsCount)
    }

    var averageStake: Int? {
        guard totalBetCount > 0 else { return nil }
        return totalStake / totalBetCount
    }
}

enum LifetimeStatsStore {
    /// Loads scope→stats map from raw Data
    static func load(from data: Data) -> [String: LifetimeStats] {
        guard !data.isEmpty else { return [:] }
        return (try? JSONDecoder().decode([String: LifetimeStats].self, from: data)) ?? [:]
    }

    /// Encodes a scope→stats map to Data
    static func save(_ map: [String: LifetimeStats]) -> Data {
        (try? JSONEncoder().encode(map)) ?? Data()
    }

    /// Re-derive stats for the given scope by absorbing every ticket exactly once.
    /// Best streak is recomputed in full each call (safer than incremental tracking).
    /// Returns the updated stats for the given scope.
    @discardableResult
    static func absorb(
        tickets: [UserTicket],
        for scope: String,
        in mapData: inout Data
    ) -> LifetimeStats {
        var map = load(from: mapData)
        var stats = map[scope] ?? LifetimeStats()

        for ticket in tickets where !ticket.isWithdrawn {
            // Stake/odds/totalBetCount: count each ticket exactly once on first sight
            if !stats.processedTicketIds.contains(ticket.id) {
                stats.processedTicketIds.insert(ticket.id)
                stats.totalBetCount += 1
                stats.totalStake += ticket.stake
                for selection in ticket.selections {
                    stats.sumOddsValue += selection.oddValue
                    stats.oddsCount += 1
                }
            }

            // Resolution outcome: count each ticket exactly once on first settlement
            if ticket.isResultKnown && !stats.settledTicketIds.contains(ticket.id) {
                stats.settledTicketIds.insert(ticket.id)
                stats.resolvedCount += 1
                if ticket.wasWon {
                    stats.wonCount += 1
                } else {
                    stats.lostCount += 1
                }
            }
        }

        // Best streak: recomputed full each call by walking settled tickets in date order
        let resolvedSorted = tickets
            .filter { $0.isResultKnown && !$0.isWithdrawn }
            .sorted { $0.date < $1.date }
        var run = 0
        var best = stats.bestStreak
        for t in resolvedSorted {
            if t.wasWon {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        stats.bestStreak = best

        map[scope] = stats
        mapData = save(map)
        return stats
    }

    /// Returns stats for the scope, or empty stats if not present
    static func read(scope: String, from data: Data) -> LifetimeStats {
        load(from: data)[scope] ?? LifetimeStats()
    }
}
