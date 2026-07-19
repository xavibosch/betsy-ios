import Foundation

// MARK: - Arena / Duel models

struct ArenaMatch: Identifiable, Codable, Equatable {
    let id: String
    let home: String
    let away: String
    let league: String
    let startDate: Date?
    let odds: [Odd]
}

struct ArenaBetSelection: Identifiable, Codable, Equatable {
    var id: String { "\(matchId)_\(oddLabel)" }
    let matchId: String
    let home: String
    let away: String
    let oddLabel: String
    let oddValue: Double
}

struct ArenaDuel: Identifiable, Codable, Equatable {
    let id: String
    let leagueId: String
    let challengerId: String
    let challengerName: String
    let opponentId: String
    let opponentName: String
    let wager: Int
    let status: String
    let createdAt: Date?
    let matches: [ArenaMatch]
    let challengerSelections: [ArenaBetSelection]
    let opponentSelections: [ArenaBetSelection]
    let winnerId: String?
    let loserId: String?
}
