import Foundation

struct UserTicket: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    let selections: [BetSelection]
    let stake: Int
    let potentialPayout: Int
    let potentialNetProfit: Int
    var appliedPowerUp: PowerUpType? = nil
    var lifelineConsumed: Bool = false
    var isResultKnown: Bool = false
    var wasWon: Bool = false
    var withdrawnAt: Date? = nil
    var withdrawalAmount: Int? = nil
    var source: String = "standard"
    var contextTitle: String? = nil
    var externalId: String? = nil

    var potentialWin: Int { potentialPayout }
    var isWithdrawn: Bool { withdrawnAt != nil }
    var isArena: Bool { source == "arena" }

    init(
        id: UUID = UUID(),
        date: Date,
        selections: [BetSelection],
        stake: Int,
        potentialPayout: Int,
        potentialNetProfit: Int? = nil,
        appliedPowerUp: PowerUpType? = nil,
        lifelineConsumed: Bool = false,
        isResultKnown: Bool = false,
        wasWon: Bool = false,
        withdrawnAt: Date? = nil,
        withdrawalAmount: Int? = nil,
        source: String = "standard",
        contextTitle: String? = nil,
        externalId: String? = nil
    ) {
        self.id = id
        self.date = date
        self.selections = selections
        self.stake = stake
        self.potentialPayout = potentialPayout
        self.potentialNetProfit = potentialNetProfit ?? max(potentialPayout - stake, 0)
        self.appliedPowerUp = appliedPowerUp
        self.lifelineConsumed = lifelineConsumed
        self.isResultKnown = isResultKnown
        self.wasWon = wasWon
        self.withdrawnAt = withdrawnAt
        self.withdrawalAmount = withdrawalAmount
        self.source = source
        self.contextTitle = contextTitle
        self.externalId = externalId
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case selections
        case stake
        case potentialPayout
        case potentialNetProfit
        case potentialWin
        case appliedPowerUp
        case lifelineConsumed
        case isResultKnown
        case wasWon
        case withdrawnAt
        case withdrawalAmount
        case source
        case contextTitle
        case externalId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decode(Date.self, forKey: .date)
        selections = try container.decode([BetSelection].self, forKey: .selections)
        let decodedStake = try container.decodeIfPresent(Int.self, forKey: .stake)
        let legacyPotentialWin = try container.decodeIfPresent(Int.self, forKey: .potentialWin) ?? 0
        let decodedPayout = try container.decodeIfPresent(Int.self, forKey: .potentialPayout) ?? legacyPotentialWin
        stake = decodedStake ?? max(min(decodedPayout / 10, decodedPayout), 1)
        potentialPayout = decodedPayout
        potentialNetProfit = try container.decodeIfPresent(Int.self, forKey: .potentialNetProfit) ?? max(decodedPayout - stake, 0)
        appliedPowerUp = try container.decodeIfPresent(PowerUpType.self, forKey: .appliedPowerUp)
        lifelineConsumed = try container.decodeIfPresent(Bool.self, forKey: .lifelineConsumed) ?? false
        isResultKnown = try container.decodeIfPresent(Bool.self, forKey: .isResultKnown) ?? false
        wasWon = try container.decodeIfPresent(Bool.self, forKey: .wasWon) ?? false
        withdrawnAt = try container.decodeIfPresent(Date.self, forKey: .withdrawnAt)
        withdrawalAmount = try container.decodeIfPresent(Int.self, forKey: .withdrawalAmount)
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? "standard"
        contextTitle = try container.decodeIfPresent(String.self, forKey: .contextTitle)
        externalId = try container.decodeIfPresent(String.self, forKey: .externalId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(selections, forKey: .selections)
        try container.encode(stake, forKey: .stake)
        try container.encode(potentialPayout, forKey: .potentialPayout)
        try container.encode(potentialNetProfit, forKey: .potentialNetProfit)
        try container.encode(appliedPowerUp, forKey: .appliedPowerUp)
        try container.encode(lifelineConsumed, forKey: .lifelineConsumed)
        try container.encode(isResultKnown, forKey: .isResultKnown)
        try container.encode(wasWon, forKey: .wasWon)
        try container.encodeIfPresent(withdrawnAt, forKey: .withdrawnAt)
        try container.encodeIfPresent(withdrawalAmount, forKey: .withdrawalAmount)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(contextTitle, forKey: .contextTitle)
        try container.encodeIfPresent(externalId, forKey: .externalId)
    }
}
