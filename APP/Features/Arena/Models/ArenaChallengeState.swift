import SwiftUI

enum ArenaChallengeState: String {
    case idle
    case preparing
    case pending
    case incoming
    case active
    case rejected
    case resolved

    func label(lang: AppLang) -> String {
        switch self {
        case .idle:
            return lang == .es ? "Sin retos" : "No challenge"
        case .preparing:
            return lang == .es ? "En preparación" : "Preparing"
        case .pending:
            return lang == .es ? "Esperando respuesta" : "Waiting response"
        case .incoming:
            return lang == .es ? "Reto recibido" : "Challenge received"
        case .active:
            return lang == .es ? "En juego" : "In play"
        case .rejected:
            return lang == .es ? "Rechazado" : "Rejected"
        case .resolved:
            return lang == .es ? "Resuelto" : "Resolved"
        }
    }

    var systemImage: String {
        switch self {
        case .idle:
            return "bolt.slash"
        case .preparing:
            return "square.and.pencil"
        case .pending:
            return "hourglass"
        case .incoming:
            return "tray.and.arrow.down"
        case .active:
            return "flame"
        case .rejected:
            return "xmark"
        case .resolved:
            return "checkmark"
        }
    }

    var prefersDarkSurface: Bool {
        switch self {
        case .preparing, .incoming, .active:
            return true
        case .idle, .pending, .rejected, .resolved:
            return false
        }
    }

    var cardBackground: Color {
        switch self {
        case .preparing:
            return Theme.bg
        case .incoming:
            return Theme.cardAlt
        case .active:
            return Theme.card
        case .idle, .pending, .rejected, .resolved:
            return Theme.paper
        }
    }

    var cardBorder: Color {
        prefersDarkSurface ? Theme.bg : Theme.paperLine
    }

    var primaryTextColor: Color {
        prefersDarkSurface ? Theme.paper : Theme.bg
    }

    var secondaryTextColor: Color {
        prefersDarkSurface ? Theme.paper.opacity(0.72) : Theme.bg.opacity(0.62)
    }

    var badgeBackground: Color {
        prefersDarkSurface ? Theme.paper : Theme.bg
    }

    var badgeForeground: Color {
        prefersDarkSurface ? Theme.bg : Theme.paper
    }
}
