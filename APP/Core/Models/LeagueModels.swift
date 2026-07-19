import Foundation

// MARK: - League visibility

enum LeagueVisibility: String, Codable, CaseIterable {
    case privateLeague = "private"
    case publicLeague  = "public"

    func title(lang: AppLang) -> String {
        switch self {
        case .privateLeague: return lang == .es ? "Privada" : "Private"
        case .publicLeague:  return lang == .es ? "Pública" : "Public"
        }
    }
}

// MARK: - Competitions

enum LeagueCompetition: String, Codable, CaseIterable, Identifiable {
    case nba        = "NBA"
    case laLiga     = "LaLiga"
    case premier    = "Premier"
    case bundesliga = "Bundesliga"
    case serieA     = "Serie A"
    case ligue1     = "Ligue 1"

    var id: String { rawValue }

    func title(lang: AppLang) -> String { rawValue }

    var sportKeys: [String] {
        switch self {
        case .nba:        return ["basketball_nba"]
        case .laLiga:     return ["soccer_spain_la_liga", "soccer_spain_copa_del_rey"]
        case .premier:    return ["soccer_epl", "soccer_england_fa_cup", "soccer_england_efl_cup"]
        case .bundesliga: return ["soccer_germany_bundesliga", "soccer_germany_dfb_pokal"]
        case .serieA:     return ["soccer_italy_serie_a", "soccer_italy_coppa_italia"]
        case .ligue1:     return ["soccer_france_ligue_one", "soccer_france_coupe_de_france"]
        }
    }

    static func competition(forSportKey sportKey: String) -> LeagueCompetition? {
        allCases.first { $0.sportKeys.contains(sportKey) }
    }
}

// MARK: - Bet window

enum LeagueBetWindowPreset: String, Codable, CaseIterable {
    case daily
    case weekdays
    case weekend
    case custom

    func title(lang: AppLang) -> String {
        switch self {
        case .daily:    return lang == .es ? "Todos los días" : "Every day"
        case .weekdays: return lang == .es ? "Entre semana"   : "Weekdays"
        case .weekend:  return lang == .es ? "Fin de semana"  : "Weekend"
        case .custom:   return lang == .es ? "Personalizada"  : "Custom"
        }
    }
}

enum LeagueWeekday: String, Codable, CaseIterable, Identifiable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: String { rawValue }

    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1; case .monday: return 2; case .tuesday:   return 3
        case .wednesday: return 4; case .thursday: return 5
        case .friday: return 6; case .saturday: return 7
        }
    }

    func shortTitle(lang: AppLang) -> String {
        switch (self, lang) {
        case (.monday, .es): return "L"; case (.tuesday, .es):    return "M"
        case (.wednesday, .es): return "X"; case (.thursday, .es): return "J"
        case (.friday, .es): return "V"; case (.saturday, .es):   return "S"
        case (.sunday, .es): return "D"
        case (.monday, .en): return "M"; case (.tuesday, .en):    return "T"
        case (.wednesday, .en): return "W"; case (.thursday, .en): return "T"
        case (.friday, .en): return "F"; case (.saturday, .en):   return "S"
        case (.sunday, .en): return "S"
        }
    }

    func fullTitle(lang: AppLang) -> String {
        switch (self, lang) {
        case (.monday, .es): return "Lunes";     case (.tuesday, .es):    return "Martes"
        case (.wednesday, .es): return "Miércoles"; case (.thursday, .es): return "Jueves"
        case (.friday, .es): return "Viernes";   case (.saturday, .es):   return "Sábado"
        case (.sunday, .es): return "Domingo"
        case (.monday, .en): return "Monday";    case (.tuesday, .en):    return "Tuesday"
        case (.wednesday, .en): return "Wednesday"; case (.thursday, .en): return "Thursday"
        case (.friday, .en): return "Friday";    case (.saturday, .en):   return "Saturday"
        case (.sunday, .en): return "Sunday"
        }
    }
}

// MARK: - League settings

struct LeagueSettings: Codable, Equatable {
    var visibility: LeagueVisibility = .privateLeague
    var maxParticipants: Int? = nil
    var allowedCompetitions: [LeagueCompetition] = LeagueCompetition.allCases
    var betWindowPreset: LeagueBetWindowPreset = .daily
    var activeWeekdays: [LeagueWeekday] = []
    var challengesOutsideBetWindow: Bool = true
    var initialBalance: Int = 100
    var betsPerActiveDay: Int = 3

    static let legacyDefaults = LeagueSettings()

    var resolvedWeekdays: [LeagueWeekday] {
        switch betWindowPreset {
        case .daily:    return LeagueWeekday.allCases
        case .weekdays: return [.monday, .tuesday, .wednesday, .thursday, .friday]
        case .weekend:  return [.friday, .saturday, .sunday]
        case .custom:   return activeWeekdays.sorted { $0.calendarWeekday < $1.calendarWeekday }
        }
    }

    func isBetDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return resolvedWeekdays.contains(where: { $0.calendarWeekday == weekday })
    }
}

// MARK: - League create

struct LeagueCreateRequest {
    let name: String
    let settings: LeagueSettings
}

struct LeagueCreateDraft {
    var name: String = ""
    var visibility: LeagueVisibility = .privateLeague
    var maxParticipantsSelection: Int = 6
    var maxParticipantsCustom: String = ""
    var allowedCompetitions: Set<LeagueCompetition> = [.nba, .laLiga]
    var betWindowPreset: LeagueBetWindowPreset = .daily
    var activeWeekdays: Set<LeagueWeekday> = Set(LeagueWeekday.allCases)
    var challengesOutsideBetWindow: Bool = true
    var initialBalanceSelection: Int = 1000
    var initialBalanceCustom: String = ""
    var betsPerActiveDaySelection: Int = 3

    private var customMaxParticipantsValue: Int? {
        guard maxParticipantsSelection == -1,
              let value = Int(maxParticipantsCustom.trimmingCharacters(in: .whitespacesAndNewlines)),
              value >= 2 else { return nil }
        return value
    }

    private var customInitialBalanceValue: Int? {
        guard initialBalanceSelection == -1,
              let value = Int(initialBalanceCustom.trimmingCharacters(in: .whitespacesAndNewlines)),
              value > 0 else { return nil }
        return value
    }

    var resolvedMaxParticipants: Int {
        maxParticipantsSelection == -1 ? (customMaxParticipantsValue ?? 2) : max(maxParticipantsSelection, 2)
    }

    var resolvedInitialBalance: Int {
        initialBalanceSelection == -1 ? (customInitialBalanceValue ?? 1) : max(initialBalanceSelection, 1)
    }

    var isBasicStepValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (maxParticipantsSelection != -1 || customMaxParticipantsValue != nil)
            && resolvedMaxParticipants >= 2
    }
    var isCompetitionsStepValid: Bool { !allowedCompetitions.isEmpty }
    var isWindowStepValid: Bool       { betWindowPreset != .custom || !activeWeekdays.isEmpty }
    var isEconomyStepValid: Bool {
        (initialBalanceSelection != -1 || customInitialBalanceValue != nil)
            && resolvedInitialBalance > 0
            && betsPerActiveDaySelection > 0
    }
    var isReadyToCreate: Bool {
        isBasicStepValid && isCompetitionsStepValid && isWindowStepValid && isEconomyStepValid
    }

    var request: LeagueCreateRequest {
        LeagueCreateRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            settings: LeagueSettings(
                visibility: visibility,
                maxParticipants: resolvedMaxParticipants,
                allowedCompetitions: LeagueCompetition.allCases.filter { allowedCompetitions.contains($0) },
                betWindowPreset: betWindowPreset,
                activeWeekdays: LeagueWeekday.allCases.filter { activeWeekdays.contains($0) },
                challengesOutsideBetWindow: challengesOutsideBetWindow,
                initialBalance: resolvedInitialBalance,
                betsPerActiveDay: betsPerActiveDaySelection
            )
        )
    }

    init() {}

    init(league: FriendLeague) {
        let settings = league.settings
        name = league.name
        visibility = settings.visibility

        if let maxParticipants = settings.maxParticipants {
            if [2, 4, 6, 8, 10, 20].contains(maxParticipants) {
                maxParticipantsSelection = maxParticipants
            } else {
                maxParticipantsSelection = -1
                maxParticipantsCustom = "\(maxParticipants)"
            }
        }

        let configured = settings.allowedCompetitions.isEmpty ? LeagueCompetition.allCases : settings.allowedCompetitions
        allowedCompetitions = Set(configured)
        betWindowPreset = settings.betWindowPreset
        activeWeekdays = Set(settings.activeWeekdays.isEmpty ? settings.resolvedWeekdays : settings.activeWeekdays)
        challengesOutsideBetWindow = settings.challengesOutsideBetWindow

        if [1000, 5000, 10000, 50, 100, 250].contains(settings.initialBalance) {
            initialBalanceSelection = settings.initialBalance
        } else {
            initialBalanceSelection = -1
            initialBalanceCustom = "\(settings.initialBalance)"
        }

        betsPerActiveDaySelection = settings.betsPerActiveDay
    }
}

// MARK: - League & Member

struct FriendLeague: Identifiable, Codable {
    var id: String
    let name: String
    let code: String
    let createdBy: String?
    var members: Int
    var leaderboard: [String: Int] = ["Tú": 100]
    var settings: LeagueSettings = .legacyDefaults

    init(
        id: String, name: String, code: String,
        createdBy: String? = nil, members: Int,
        leaderboard: [String: Int] = ["Tú": 100],
        settings: LeagueSettings = .legacyDefaults
    ) {
        self.id = id; self.name = name; self.code = code
        self.createdBy = createdBy; self.members = members
        self.leaderboard = leaderboard; self.settings = settings
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, code, createdBy, members, leaderboard, settings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        name        = try c.decode(String.self, forKey: .name)
        code        = try c.decode(String.self, forKey: .code)
        createdBy   = try c.decodeIfPresent(String.self, forKey: .createdBy)
        members     = try c.decodeIfPresent(Int.self, forKey: .members) ?? 0
        leaderboard = try c.decodeIfPresent([String: Int].self, forKey: .leaderboard) ?? ["Tú": 100]
        settings    = try c.decodeIfPresent(LeagueSettings.self, forKey: .settings) ?? .legacyDefaults
    }
}

struct LeagueMember: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let points: Int
    let pointsToday: Int
    let pointsTodayDate: String
    let recoveryBoostDate: String?

    init(id: String, name: String, points: Int, pointsToday: Int,
         pointsTodayDate: String, recoveryBoostDate: String? = nil) {
        self.id = id; self.name = name; self.points = points
        self.pointsToday = pointsToday; self.pointsTodayDate = pointsTodayDate
        self.recoveryBoostDate = recoveryBoostDate
    }
}
