import Foundation

// MARK: - Challenge

struct ChallengeDraft: Codable, Equatable {
    let leagueId: String
    let opponentId: String
    let opponentName: String
    let wager: Int
}

struct Challenge: Identifiable, Codable, Equatable {
    let id: String
    let leagueId: String
    let challengerId: String
    let challengerName: String
    let opponentId: String
    let opponentName: String
    let matchHome: String
    let matchAway: String
    let selectionLabel: String
    let oddValue: Double
    let wager: Int
    let status: String
    let createdAt: Date?
    let winnerId: String?
    let loserId: String?
}
