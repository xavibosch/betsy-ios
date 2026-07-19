import Foundation

enum TicketPricingEngine {
    static func combinedOdds(for selections: [BetSelection]) -> Double {
        BettingRules.combinedOdds(for: selections)
    }

    static func potentialPayout(
        stake: Int,
        selections: [BetSelection],
        selectedPowerUp: PowerUpType?
    ) -> Int {
        BettingRules.potentialPayout(
            stake: stake,
            selections: selections,
            selectedPowerUp: selectedPowerUp
        )
    }

    static func potentialNetProfit(stake: Int, payout: Int) -> Int {
        BettingRules.potentialNetProfit(stake: stake, payout: payout)
    }

    static func makeTicket(
        date: Date = Date(),
        selections: [BetSelection],
        stake: Int,
        selectedPowerUp: PowerUpType?
    ) -> UserTicket {
        let payout = potentialPayout(
            stake: stake,
            selections: selections,
            selectedPowerUp: selectedPowerUp
        )
        return UserTicket(
            date: date,
            selections: selections,
            stake: stake,
            potentialPayout: payout,
            potentialNetProfit: potentialNetProfit(stake: stake, payout: payout),
            appliedPowerUp: selectedPowerUp
        )
    }
}
