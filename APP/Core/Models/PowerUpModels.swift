import Foundation

// MARK: - Power-up types

enum PowerUpType: String, Codable, CaseIterable {
    case multiplier
    case lifeline
}

// MARK: - Power-up models

struct PowerUp: Identifiable, Codable, Equatable {
    var id: String { type.rawValue }
    let type: PowerUpType
    let count: Int
}

struct PowerUpInventory: Codable, Equatable {
    var multiplierCount: Int
    var lifelineCount: Int

    var list: [PowerUp] {
        [
            PowerUp(type: .multiplier, count: multiplierCount),
            PowerUp(type: .lifeline, count: lifelineCount)
        ]
    }
}
