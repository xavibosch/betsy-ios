import Foundation

struct BetSelection: Identifiable, Codable, Equatable {
    var id = UUID()
    let matchId: UUID
    let eventId: String?
    let sportKey: String?
    let home: String
    let away: String
    let league: String
    let startDate: Date?
    let oddLabel: String
    let oddValue: Double
    let addedAt: Date?

    init(
        id: UUID = UUID(),
        matchId: UUID,
        eventId: String? = nil,
        sportKey: String? = nil,
        home: String,
        away: String,
        league: String,
        startDate: Date?,
        oddLabel: String,
        oddValue: Double,
        addedAt: Date?
    ) {
        self.id = id
        self.matchId = matchId
        self.eventId = eventId
        self.sportKey = sportKey
        self.home = home
        self.away = away
        self.league = league
        self.startDate = startDate
        self.oddLabel = oddLabel
        self.oddValue = oddValue
        self.addedAt = addedAt
    }
}
