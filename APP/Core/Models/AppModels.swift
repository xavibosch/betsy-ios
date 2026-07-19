import SwiftUI

// MARK: - Runtime

enum BetsyRuntime {
    static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

// MARK: - Language

enum AppLang: String, CaseIterable, Codable {
    case es, en
    var title: String { self == .es ? "Español" : "English" }
    var localeIdentifier: String { self == .es ? "es_ES" : "en_US" }

    func text(_ key: String) -> String {
        let data: [String: [AppLang: String]] = [
            "play": [.es: "Deportes", .en: "Sports"],
            "play_tab": [.es: "Jugar", .en: "Play"],
            "my_bets": [.es: "Mis Apuestas", .en: "My Bets"],
            "my_bets_title": [.es: "Mis apuestas", .en: "My Bets"],
            "leagues": [.es: "Ligas", .en: "Leagues"],
            "profile": [.es: "Perfil", .en: "Profile"],
            "stats": [.es: "Stats", .en: "Stats"],
            "sports_explorer": [.es: "Explorar deportes", .en: "Sports Explorer"],
            "dev_profile": [.es: "Perfil dev", .en: "Dev Profile"],
            "power_ups": [.es: "Potenciadores", .en: "Power-ups"],
            "welcome_title": [.es: "Bienvenido a BETSY", .en: "Welcome to BETSY"],
            "welcome_cta": [.es: "EMPEZAR A JUGAR", .en: "START PLAYING"],
            "welcome_feature_1": [.es: "Elige tu liga favorita (NBA, LaLiga...)", .en: "Pick your favorite league (NBA, LaLiga...)"],
            "welcome_feature_2": [.es: "Haz apuestas sin dinero real.", .en: "Place bets with no real money."],
            "welcome_feature_3": [.es: "Sube en el ranking y compite.", .en: "Climb the leaderboard and compete."],
            "pending": [.es: "Hoy / Pendientes", .en: "Today / Pending"],
            "history": [.es: "Historial", .en: "History"],
            "bet_button": [.es: "REVISAR APUESTA", .en: "REVIEW BET"],
            "confirm": [.es: "CONFIRMAR", .en: "CONFIRM"],
            "join": [.es: "Unirse", .en: "Join"],
            "invite": [.es: "Invitar con link", .en: "Invite with link"],
            "possible_win": [.es: "Posible ganancia", .en: "Potential win"],
            "win_rate": [.es: "Acierto", .en: "Win Rate"],
            "avg_odd": [.es: "Cuota Media", .en: "Avg Odd"],
            "placeholder_code": [.es: "Código de invitación...", .en: "Invite code..."]
        ]
        return data[key]?[self] ?? key
    }
}

// MARK: - Developer profile

enum DevProfile: String, CaseIterable, Identifiable, Codable {
    case real
    case tester1
    case tester2
    case tester3
    case tester4

    var id: String { rawValue }

    var title: String {
        switch self {
        case .real: return "Yo"
        case .tester1: return "Tester 1"
        case .tester2: return "Tester 2"
        case .tester3: return "Tester 3"
        case .tester4: return "Tester 4"
        }
    }

    var devUserId: String? {
        switch self {
        case .real: return nil
        case .tester1: return "dev_tester_1"
        case .tester2: return "dev_tester_2"
        case .tester3: return "dev_tester_3"
        case .tester4: return "dev_tester_4"
        }
    }

    var displayName: String {
        switch self {
        case .real: return ""
        case .tester1: return "Tester_1"
        case .tester2: return "Tester_2"
        case .tester3: return "Tester_3"
        case .tester4: return "Tester_4"
        }
    }

    var testerEmail: String? {
        switch self {
        case .real: return nil
        case .tester1: return "tester1@betsy.dev"
        case .tester2: return "tester2@betsy.dev"
        case .tester3: return "tester3@betsy.dev"
        case .tester4: return "tester4@betsy.dev"
        }
    }

    var vibe: (emoji: String, color: Color) {
        switch self {
        case .real:     return ("🎯", Color(red: 0.07, green: 0.07, blue: 0.08))
        case .tester1:  return ("🔥", Color(red: 0.96, green: 0.28, blue: 0.45))
        case .tester2:  return ("⚡", Color(red: 0.34, green: 0.48, blue: 0.98))
        case .tester3:  return ("🎱", Color(red: 0.56, green: 0.22, blue: 0.85))
        case .tester4:  return ("🚀", Color(red: 0.12, green: 0.70, blue: 0.45))
        }
    }
}
