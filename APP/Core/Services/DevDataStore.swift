import Foundation

// MARK: - DevDataStore
// Central local store for ALL dev-mode state.
// Nothing here ever touches Firestore or any external API.

final class DevDataStore {

    static let shared = DevDataStore()
    private init() {}

    // MARK: UserDefaults keys
    private let pointsKey = "devDataStore_memberPoints_v1"   // [String: MemberPoints]
    private let arenasKey = "devDataStore_arenas_v1"          // [leagueId: [ArenaDuel]]
    private let limitsKey = "devDataStore_arenaLimits_v1"     // [userId: dayKey]

    // MARK: - MemberPoints

    struct MemberPoints: Codable {
        var points: Int
        var pointsToday: Int
        var pointsTodayDate: String
        var recoveryBoostDate: String?
    }

    // Composite key for the dictionary
    private func memberKey(leagueId: String, userId: String) -> String { "\(leagueId):\(userId)" }

    func memberPoints(leagueId: String, userId: String) -> MemberPoints? {
        allPoints()[memberKey(leagueId: leagueId, userId: userId)]
    }

    /// Returns existing points or creates an entry at `initialPoints` and returns it.
    @discardableResult
    func initializeMember(leagueId: String, userId: String, initialPoints: Int) -> MemberPoints {
        let key = memberKey(leagueId: leagueId, userId: userId)
        var dict = allPoints()
        if let existing = dict[key] { return existing }
        let mp = MemberPoints(points: initialPoints, pointsToday: 0, pointsTodayDate: "", recoveryBoostDate: nil)
        dict[key] = mp
        savePoints(dict)
        return mp
    }

    func updateMemberPoints(leagueId: String, userId: String, points: MemberPoints) {
        var dict = allPoints()
        dict[memberKey(leagueId: leagueId, userId: userId)] = points
        savePoints(dict)
    }

    func removeMember(leagueId: String, userId: String) {
        var dict = allPoints()
        dict.removeValue(forKey: memberKey(leagueId: leagueId, userId: userId))
        savePoints(dict)
    }

    // MARK: Point adjustment (atomic helper)

    func adjustPoints(
        leagueId: String,
        userId: String,
        initialBalance: Int,
        delta: Int,
        todayKey: String
    ) {
        guard delta != 0 else { return }
        var dict = allPoints()
        let key  = memberKey(leagueId: leagueId, userId: userId)
        var mp   = dict[key] ?? MemberPoints(
            points: initialBalance, pointsToday: 0, pointsTodayDate: "", recoveryBoostDate: nil
        )
        mp.points    += delta
        mp.pointsToday = (mp.pointsTodayDate == todayKey) ? (mp.pointsToday + delta) : delta
        mp.pointsTodayDate = todayKey
        dict[key] = mp
        savePoints(dict)
    }

    // MARK: League cleanup

    func removeLeague(leagueId: String) {
        var dict = allPoints()
        dict = dict.filter { !$0.key.hasPrefix("\(leagueId):") }
        savePoints(dict)
        clearArenas(leagueId: leagueId)
    }

    // MARK: - Arenas

    func arenas(leagueId: String) -> [ArenaDuel] {
        allArenas()[leagueId] ?? []
    }

    func insertArena(_ duel: ArenaDuel, leagueId: String) {
        var list = arenas(leagueId: leagueId)
        if !list.contains(where: { $0.id == duel.id }) { list.insert(duel, at: 0) }
        saveArenas(list, leagueId: leagueId)
    }

    func updateArena(_ duel: ArenaDuel, leagueId: String) {
        var list = arenas(leagueId: leagueId)
        if let i = list.firstIndex(where: { $0.id == duel.id }) { list[i] = duel }
        else { list.insert(duel, at: 0) }
        saveArenas(list, leagueId: leagueId)
    }

    func removeArena(duelId: String, leagueId: String) {
        var list = arenas(leagueId: leagueId)
        list.removeAll(where: { $0.id == duelId })
        saveArenas(list, leagueId: leagueId)
    }

    func clearArenas(leagueId: String) {
        var dict = allArenas()
        dict.removeValue(forKey: leagueId)
        saveArenasDict(dict)
    }

    func pruneExpiredArenas(cutoff: Date) {
        var dict = allArenas()
        dict = dict.mapValues { duels in
            duels.filter { duel in
                guard duel.status == "resolved" || duel.status == "declined" else { return true }
                return (duel.createdAt ?? .distantFuture) > cutoff
            }
        }
        .filter { !$0.value.isEmpty }
        saveArenasDict(dict)
    }

    private func saveArenas(_ duels: [ArenaDuel], leagueId: String) {
        var dict = allArenas()
        dict[leagueId] = duels
        saveArenasDict(dict)
    }

    // MARK: - Arena daily limits

    func arenaChallengeDay(userId: String) -> String {
        allLimits()[userId] ?? ""
    }

    func setArenaChallengeDay(userId: String, day: String) {
        var dict = allLimits()
        dict[userId] = day
        saveLimits(dict)
    }

    func clearAllArenaDailyLimits() {
        UserDefaults.standard.removeObject(forKey: limitsKey)
    }

    // MARK: - Full reset

    func resetAll() {
        UserDefaults.standard.removeObject(forKey: pointsKey)
        UserDefaults.standard.removeObject(forKey: arenasKey)
        UserDefaults.standard.removeObject(forKey: limitsKey)
    }

    // MARK: - Private persistence helpers

    private func allPoints() -> [String: MemberPoints] {
        guard let data = UserDefaults.standard.data(forKey: pointsKey),
              let dict = try? JSONDecoder().decode([String: MemberPoints].self, from: data)
        else { return [:] }
        return dict
    }

    private func savePoints(_ dict: [String: MemberPoints]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: pointsKey)
    }

    private func allArenas() -> [String: [ArenaDuel]] {
        guard let data = UserDefaults.standard.data(forKey: arenasKey),
              let dict = try? JSONDecoder().decode([String: [ArenaDuel]].self, from: data)
        else { return [:] }
        return dict
    }

    private func saveArenasDict(_ dict: [String: [ArenaDuel]]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: arenasKey)
    }

    private func allLimits() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: limitsKey),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    private func saveLimits(_ dict: [String: String]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: limitsKey)
    }
}

enum DevSimulationClock {
    private static let offsetKey = "devSimulationDayOffset_v1"

    static var dayOffset: Int {
        UserDefaults.standard.integer(forKey: offsetKey)
    }

    static func now() -> Date {
        guard UserDefaults.standard.bool(forKey: "isDevModeActive") else { return Date() }
        return Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
    }

    @discardableResult
    static func advanceDay() -> Date {
        UserDefaults.standard.set(dayOffset + 1, forKey: offsetKey)
        return now()
    }

    static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: now())
    }

    static func cutoffDate(retentionDays: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -retentionDays, to: now()) ?? now()
    }
}
