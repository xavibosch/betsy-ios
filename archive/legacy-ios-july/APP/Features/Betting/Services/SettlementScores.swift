import Foundation

/// Shared score fetcher for real settlement. One repository for the whole app (respects
/// dev/fake mode), fan-out per sport key with `daysFrom=3` so results from the last few
/// days are still retrievable, and a short throttle so settlement checks from several
/// screens can't burn API credits in bursts.
enum SettlementScores {
    private static let repository = SportsDataRepository()
    private static let lock = NSLock()
    private static var lastFetchAt: [String: Date] = [:]
    private static var cached: [String: MatchScore] = [:]
    private static let throttle: TimeInterval = 60

    /// Sport keys worth checking for a league: its configured competitions plus the
    /// always-on World Cup (special competition, never stored in league settings).
    static func sportKeys(for league: FriendLeague?) -> Set<String> {
        let configured = league?.settings.allowedCompetitions.flatMap(\.sportKeys) ?? []
        return Set(configured + LeagueCompetition.worldCup.sportKeys)
    }

    /// Drop the per-sport throttle timestamps so the next `fetch` re-queries immediately.
    /// Called when the Odds API key rotates — the previous fetch hit an exhausted key and
    /// returned nothing, so we must retry now with the new key instead of waiting out the throttle.
    static func clearThrottle() {
        lock.lock(); lastFetchAt = [:]; lock.unlock()
    }

    /// Fetch completed/live scores for the given sports, merged by eventId.
    /// Sports fetched less than `throttle` seconds ago are served from cache.
    static func fetch(
        sportKeys: Set<String>,
        completion: @escaping ([String: MatchScore]) -> Void
    ) {
        let keys = sportKeys.filter { !$0.isEmpty }
        guard !keys.isEmpty else {
            completion([:])
            return
        }

        let now = Date()
        lock.lock()
        let pending = keys.filter { key in
            guard let last = lastFetchAt[key] else { return true }
            return now.timeIntervalSince(last) >= throttle
        }
        pending.forEach { lastFetchAt[$0] = now }
        lock.unlock()

        guard !pending.isEmpty else {
            lock.lock(); let snapshot = cached; lock.unlock()
            DispatchQueue.main.async { completion(snapshot) }
            return
        }

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "settlement.scores.merge")
        var merged: [String: MatchScore] = [:]

        for sport in pending {
            group.enter()
            repository.fetchScores(for: sport, daysFrom: 3) { scores in
                queue.sync {
                    for (eventId, score) in scores { merged[eventId] = score }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            lock.lock()
            cached.merge(merged) { _, new in new }
            let snapshot = cached
            lock.unlock()
            completion(snapshot)
        }
    }

}
