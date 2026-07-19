import Foundation

/// Goal-level stats for a finished match (football-data.org): who scored, who assisted,
/// who scored first. Lets goalscorer/assist picks settle with REAL data.
struct MatchGoalStats: Codable {
    let scorers: [String]      // normalized, may repeat for braces
    let assisters: [String]
    let firstScorer: String?
    let fetchedAt: Date
    var hasData: Bool { !scorers.isEmpty }
}

/// football-data.org client (free tier). Permanent cache per match — finished goals
/// never change. Honors the X-Requests-Available-Minute throttle header.
enum MatchStatsService {
    private static let baseURL = "https://api.football-data.org/v4"
    private static let cacheKey = "betsyMatchGoalStatsV1"
    private static let lock = NSLock()
    private static var throttled = false

    /// Unique (home, away) pairs from open picks that need goal stats to settle.
    static func statsPairs(in tickets: [UserTicket]) -> [(home: String, away: String)] {
        let needy: Set<String> = ["player_goal_scorer_anytime", "player_first_goal_scorer", "player_assists"]
        var seen = Set<String>()
        var pairs: [(String, String)] = []
        for t in tickets where !t.isResultKnown && !t.isWithdrawn {
            for s in t.selections where needy.contains(s.marketKey ?? "") {
                let key = "\(s.home.lowercased())|\(s.away.lowercased())"
                if seen.insert(key).inserted { pairs.append((s.home, s.away)) }
            }
        }
        return pairs
    }

    /// Strip accents + symbols, lowercase: "Raúl Jiménez" → "raul jimenez".
    static func normalized(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func loadCache() -> [String: MatchGoalStats] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let dict = try? JSONDecoder().decode([String: MatchGoalStats].self, from: data) else { return [:] }
        return dict
    }

    private static func saveCache(_ dict: [String: MatchGoalStats]) {
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private static func pairKey(_ home: String, _ away: String) -> String {
        "\(home.lowercased())|\(away.lowercased())"
    }

    private static func teamsMatch(_ a: String, _ b: String) -> Bool {
        let na = normalized(a).replacingOccurrences(of: " ", with: "")
        let nb = normalized(b).replacingOccurrences(of: " ", with: "")
        if na.isEmpty || nb.isEmpty { return false }
        return na.contains(nb) || nb.contains(na)
            || na.prefix(5) == nb.prefix(5)
    }

    /// Fetch goal stats for the given (home, away) pairs. Cached results return instantly;
    /// network only for unseen finished matches. Completion on main, keyed by "home|away".
    static func fetch(
        pairs: [(home: String, away: String)],
        completion: @escaping ([String: MatchGoalStats]) -> Void
    ) {
        var cache = loadCache()
        let pending = pairs.filter { cache[pairKey($0.home, $0.away)]?.hasData != true }
        guard !pending.isEmpty, !throttled else {
            DispatchQueue.main.async { completion(cache) }
            return
        }

        // 1 call: every match of the last 3 days across free competitions.
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        let to = fmt.string(from: Date())
        let from = fmt.string(from: Date().addingTimeInterval(-3 * 24 * 3600))
        request(path: "/matches?dateFrom=\(from)&dateTo=\(to)") { json in
            guard let json, let matches = json["matches"] as? [[String: Any]] else {
                DispatchQueue.main.async { completion(cache) }
                return
            }

            // Map our pending pairs → football-data match ids (fuzzy team names).
            var idForPair: [(key: String, id: Int)] = []
            for pair in pending {
                for m in matches {
                    guard (m["status"] as? String) == "FINISHED",
                          let ht = (m["homeTeam"] as? [String: Any])?["name"] as? String,
                          let at = (m["awayTeam"] as? [String: Any])?["name"] as? String,
                          let id = m["id"] as? Int else { continue }
                    if teamsMatch(pair.home, ht), teamsMatch(pair.away, at) {
                        idForPair.append((pairKey(pair.home, pair.away), id))
                        break
                    }
                }
            }
            guard !idForPair.isEmpty else {
                DispatchQueue.main.async { completion(cache) }
                return
            }

            // Detail calls (max 6 per pass to respect 10/min free limit).
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "matchstats.merge")
            for (key, id) in idForPair.prefix(6) {
                group.enter()
                request(path: "/matches/\(id)") { detail in
                    defer { group.leave() }
                    guard let detail, let goals = detail["goals"] as? [[String: Any]] else { return }
                    var scorers: [String] = []
                    var assisters: [String] = []
                    for g in goals {
                        if let s = (g["scorer"] as? [String: Any])?["name"] as? String {
                            scorers.append(normalized(s))
                        }
                        if let a = (g["assist"] as? [String: Any])?["name"] as? String {
                            assisters.append(normalized(a))
                        }
                    }
                    let stats = MatchGoalStats(
                        scorers: scorers,
                        assisters: assisters,
                        firstScorer: scorers.first,
                        fetchedAt: Date()
                    )
                    queue.sync { cache[key] = stats }
                }
            }
            group.notify(queue: .main) {
                lock.lock()
                saveCache(cache)
                lock.unlock()
                completion(cache)
            }
        }
    }

    private static func request(path: String, completion: @escaping ([String: Any]?) -> Void) {
        // Split any inline query off the path so it can be forwarded through the proxy,
        // which appends the football-data.org key (X-Auth-Token) server-side. The key
        // never ships in the app binary — see SportsProxy / Cloud Function `apiProxy`.
        let parts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let pathOnly = String(parts.first ?? "")
        var query: [String: String] = [:]
        if parts.count > 1 {
            for pair in parts[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 { query[String(kv[0])] = String(kv[1]) }
            }
        }
        guard let url = SportsProxy.url(.footballdata, path: "/v4" + pathOnly, query: query) else {
            completion(nil)
            return
        }
        SportsProxy.authorize(url, .footballdata, timeout: 10) { req in
            URLSession.shared.dataTask(with: req) { data, response, _ in
                // Honor the rate limiter — Daniel asked nicely.
                if let http = response as? HTTPURLResponse {
                    if let raw = http.value(forHTTPHeaderField: "X-Requests-Available-Minute"),
                       let left = Int(raw), left <= 1 {
                        throttled = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 65) { throttled = false }
                    }
                    guard (200...299).contains(http.statusCode) else {
                        completion(nil)
                        return
                    }
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(nil)
                    return
                }
                completion(json)
            }.resume()
        }
    }
}
