import Foundation

struct LiveMatchSnapshot: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let eventId: String
    let sportKey: String?
    let leagueName: String
    let homeTeam: String
    let awayTeam: String
    let homeScore: Int?
    let awayScore: Int?
    let status: FixtureStatus
    let elapsed: Int?
    let lastUpdated: Date?
}
