import Foundation

struct SportsSimulationSettings: Codable, Equatable {
    var seed: Int
    var accelerationMultiplier: Double
    var usesWallClock: Bool

    init(
        seed: Int = 7,
        accelerationMultiplier: Double = 1,
        usesWallClock: Bool = true
    ) {
        self.seed = seed
        self.accelerationMultiplier = accelerationMultiplier
        self.usesWallClock = usesWallClock
    }

    static let `default` = SportsSimulationSettings()
}
