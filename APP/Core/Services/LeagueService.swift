import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - LeagueService (base class)
// Domain extensions live alongside this file:
//   LeagueService+Auth.swift       → registerAccount, signIn, passwordReset, anonymous auth
//   LeagueService+Dev.swift        → dev profiles, data reset, account deletion
//   LeagueService+Leagues.swift    → CRUD leagues, join/leave, members
//   LeagueService+Challenges.swift → 1v1 match challenges
//   LeagueService+Points.swift     → points, transfers, recovery boost, today key
//   LeagueService+PowerUps.swift   → daily power-up grant / consume
//   LeagueService+Arena.swift      → Arena duels full lifecycle
//   LeagueService+Helpers.swift    → Firestore encode/decode helpers, code generator

final class LeagueService: ObservableObject {

    // MARK: Published state
    @Published var myLeagues: [FriendLeague] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var membersByLeague: [String: [LeagueMember]] = [:]
    @Published var membersLoadingId: String? = nil
    @Published var myPowerUpsByLeague: [String: PowerUpInventory] = [:]
    @Published var challengesByLeague: [String: [Challenge]] = [:]
    @Published var activeChallenge: ChallengeDraft? = nil
    @Published var pendingArenaInvite: ArenaDuel? = nil
    @Published var outgoingArenaInvite: ArenaDuel? = nil
    @Published var declinedArenaInvite: ArenaDuel? = nil
    @Published var activeArena: ArenaDuel? = nil
    @Published var arenasByLeague: [String: [ArenaDuel]] = [:]
    @Published var currentDevProfile: DevProfile = .real

    // MARK: Private state
    lazy var db = Firestore.firestore()
    var listener: ListenerRegistration?
    var userId: String?
    @AppStorage("displayName") var displayName: String = ""
    @AppStorage("profileEmail") var profileEmail: String = ""
    @AppStorage("devProfile") var devProfileRaw: String = DevProfile.real.rawValue
    @AppStorage("selectedLeagueId") var selectedLeagueId: String = ""
    var powerUpListener: ListenerRegistration?
    var challengeListener: ListenerRegistration?
    var arenaListener: ListenerRegistration?

    // MARK: Computed
    var currentUserId: String? { effectiveUserId }

    var effectiveUserId: String? {
        if let devId = currentDevProfile.devUserId { return devId }
        if isDevModeActive { return userId ?? "dev_local_real" }
        guard let uid = userId else { return nil }
        return uid
    }

    var isDevModeActive: Bool {
        UserDefaults.standard.bool(forKey: "isDevModeActive")
    }

    var effectiveDisplayName: String {
        if currentDevProfile == .real {
            if !displayName.isEmpty { return displayName }
            return defaultDisplayName(uid: userId ?? "user")
        }
        return currentDevProfile.displayName
    }

    func localized(_ es: String, _ en: String) -> String {
        UserDefaults.standard.string(forKey: "selectedLanguage") == AppLang.en.rawValue ? en : es
    }

    // MARK: Init
    init(preview: Bool = BetsyRuntime.isPreview) {
        currentDevProfile = DevProfile(rawValue: devProfileRaw) ?? .real
        if preview {
            userId = "preview_user"
            if displayName.isEmpty { displayName = "Preview Player" }
            return
        }
        signInAnonymously()
    }

    // MARK: Preview mock
    static func previewMock() -> LeagueService {
        let service = LeagueService(preview: true)
        let league = FriendLeague(
            id: "preview_league",
            name: "Preview League",
            code: "BET123",
            createdBy: "preview_user",
            members: 3,
            leaderboard: ["Preview Player": 1450],
            settings: LeagueSettings(
                visibility: .privateLeague,
                maxParticipants: 6,
                allowedCompetitions: [.nba, .laLiga],
                betWindowPreset: .weekend,
                activeWeekdays: [],
                challengesOutsideBetWindow: true,
                initialBalance: 100,
                betsPerActiveDay: 3
            )
        )
        let todayKey: String = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar.current
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }()

        service.userId = "preview_user"
        service.displayName = "Preview Player"
        service.myLeagues = [league]
        service.membersByLeague[league.id] = [
            LeagueMember(id: "preview_user", name: "Preview Player", points: 1450, pointsToday: 120, pointsTodayDate: todayKey),
            LeagueMember(id: "member_2",     name: "Member 2",       points: 1530, pointsToday: 140, pointsTodayDate: todayKey),
            LeagueMember(id: "member_3",     name: "Member 3",       points: 1390, pointsToday: -20, pointsTodayDate: todayKey)
        ]
        service.myPowerUpsByLeague[league.id] = PowerUpInventory(multiplierCount: 1, lifelineCount: 1)
        service.pendingArenaInvite = ArenaDuel(
            id: "preview_arena",
            leagueId: league.id,
            challengerId: "member_2",
            challengerName: "Member 2",
            opponentId: "preview_user",
            opponentName: "Preview Player",
            wager: 20,
            status: "pending",
            createdAt: Date(),
            matches: [
                ArenaMatch(
                    id: "preview_match",
                    home: "Man City",
                    away: "Arsenal",
                    league: "Premier League",
                    startDate: Date().addingTimeInterval(3600),
                    odds: [
                        Odd(label: "1", value: 2.60),
                        Odd(label: "X", value: 3.40),
                        Odd(label: "2", value: 2.80)
                    ]
                )
            ],
            challengerSelections: [],
            opponentSelections: [],
            winnerId: nil,
            loserId: nil
        )
        return service
    }

    // MARK: Reset session
    func resetSession() {
        try? Auth.auth().signOut()
        userId = nil
        myLeagues = []
        membersByLeague = [:]
        myPowerUpsByLeague = [:]
        challengesByLeague = [:]
        activeChallenge = nil
        pendingArenaInvite = nil
        outgoingArenaInvite = nil
        declinedArenaInvite = nil
        activeArena = nil
        arenasByLeague = [:]
        selectedLeagueId = ""
        powerUpListener?.remove()
        challengeListener?.remove()
        arenaListener?.remove()
        NotificationCenter.default.post(name: .betsyAuthChanged, object: nil)
        signInAnonymously()
    }
}
