import Foundation

enum BetValidationEngine {
    static func conflictingSelectionIds(_ selections: [BetSelection]) -> Set<UUID> {
        BettingRules.conflictingSelectionIds(selections)
    }

    static func hasReachedDailyLimit(currentDailyBets: Int, dailyBetLimit: Int) -> Bool {
        BettingRules.hasReachedDailyLimit(currentDailyBets: currentDailyBets, dailyBetLimit: dailyBetLimit)
    }

    static func remainingDailyBets(currentDailyBets: Int, dailyBetLimit: Int) -> Int {
        BettingRules.remainingDailyBets(currentDailyBets: currentDailyBets, dailyBetLimit: dailyBetLimit)
    }

    static func isLifelineSelectionCountValid(
        selectedPowerUp: PowerUpType?,
        selectionCount: Int
    ) -> Bool {
        BettingRules.isLifelineSelectionCountValid(
            selectedPowerUp: selectedPowerUp,
            selectionCount: selectionCount
        )
    }

    static func normalizedStake(requestedStake: Int, availableBalance: Int) -> Int {
        BettingRules.normalizedStake(requestedStake: requestedStake, availableBalance: availableBalance)
    }

    static func isStakeValid(stake: Int, availableBalance: Int) -> Bool {
        BettingRules.isStakeValid(stake: stake, availableBalance: availableBalance)
    }

    static func canWithdraw(ticket: UserTicket, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        BettingRules.canWithdraw(ticket: ticket, now: now, calendar: calendar)
    }

    static func cashOutQuote(ticket: UserTicket, now: Date = Date(), calendar: Calendar = .current) -> TicketCashOutQuote {
        BettingRules.cashOutQuote(ticket: ticket, now: now, calendar: calendar)
    }

    static func shouldResetDailyBets(lastBetDate: String?, todayKey: String) -> Bool {
        BettingRules.shouldResetDailyBets(lastBetDate: lastBetDate, todayKey: todayKey)
    }
}
