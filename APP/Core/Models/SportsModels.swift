import Foundation

// MARK: - Date filter

enum MatchDateFilter: String, CaseIterable {
    case all
    case today
    case tomorrow
    case custom

    func title(lang: AppLang) -> String {
        switch self {
        case .all:      return lang == .es ? "Todos"  : "All"
        case .today:    return lang == .es ? "Hoy"    : "Today"
        case .tomorrow: return lang == .es ? "Mañana" : "Tomorrow"
        case .custom:   return lang == .es ? "Fecha"  : "Date"
        }
    }
}

// MARK: - Odds & markets

struct Odd: Identifiable, Hashable, Codable {
    var id: String {
        let key = marketKey ?? "main"
        if let point { return "\(key)_\(label)_\(value)_\(point)" }
        return "\(key)_\(label)_\(value)"
    }

    let label: String
    let value: Double
    let marketKey: String?
    let marketName: String?
    let point: Double?

    init(label: String, value: Double, marketKey: String? = nil, marketName: String? = nil, point: Double? = nil) {
        self.label = label
        self.value = value
        self.marketKey = marketKey
        self.marketName = marketName
        self.point = point
    }
}

struct BetMarket: Identifiable, Hashable, Codable {
    var id: String { key }
    let key: String
    let name: String
    let outcomes: [Odd]
}

// MARK: - Match

struct Match: Identifiable, Equatable {
    let id = UUID()
    let eventId: String?
    let sportKey: String
    let home: String
    let away: String
    let league: String
    let odds: [Odd]
    let startDate: Date?
    let markets: [BetMarket]

    init(
        eventId: String? = nil,
        sportKey: String = "",
        home: String,
        away: String,
        league: String,
        odds: [Odd],
        startDate: Date?,
        markets: [BetMarket]
    ) {
        self.eventId = eventId
        self.sportKey = sportKey
        self.home = home
        self.away = away
        self.league = league
        self.odds = odds
        self.startDate = startDate
        self.markets = markets
    }
}

struct MatchScore: Equatable {
    let eventId: String
    let home: String
    let away: String
    let homeScore: Int?
    let awayScore: Int?
    let completed: Bool
    let lastUpdate: Date?
}

// MARK: - Pick label helpers

func canonicalPickCode(from label: String) -> String? {
    let normalized = label
        .lowercased()
        .replacingOccurrences(of: "ganador ·", with: "")
        .replacingOccurrences(of: "winner ·", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    if normalized == "1" || normalized == "local" || normalized == "home" { return "1" }
    if normalized == "2" || normalized == "visitante" || normalized == "away" { return "2" }
    if normalized == "x" || normalized == "draw" || normalized == "empate" || normalized == "tie" { return "X" }

    if normalized.hasSuffix("· 1") { return "1" }
    if normalized.hasSuffix("· 2") { return "2" }
    if normalized.hasSuffix("· x") { return "X" }

    return nil
}

func readableOddLabel(_ oddLabel: String, home: String, away: String, lang: AppLang) -> String {
    guard let code = canonicalPickCode(from: oddLabel) else { return oddLabel }
    switch code {
    case "1": return home
    case "2": return away
    case "X": return lang == .es ? "Empate" : "Draw"
    default:  return oddLabel
    }
}

// MARK: - Sample data (for previews & dev)

let matchesData: [Match] = [
    Match(
        sportKey: "soccer_spain_la_liga",
        home: "Real Madrid",
        away: "Barça",
        league: "LaLiga",
        odds: [Odd(label: "1", value: 2.10), Odd(label: "X", value: 3.40), Odd(label: "2", value: 2.90)],
        startDate: Date(),
        markets: [BetMarket(key: "h2h", name: "Ganador",
                            outcomes: [Odd(label: "1", value: 2.10), Odd(label: "X", value: 3.40), Odd(label: "2", value: 2.90)])]
    ),
    Match(
        sportKey: "basketball_nba",
        home: "Lakers",
        away: "Celtics",
        league: "NBA",
        odds: [Odd(label: "1", value: 1.85), Odd(label: "2", value: 1.95)],
        startDate: Date(),
        markets: [BetMarket(key: "h2h", name: "Ganador",
                            outcomes: [Odd(label: "1", value: 1.85), Odd(label: "2", value: 1.95)])]
    )
]
