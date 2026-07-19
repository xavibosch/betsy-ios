import Foundation

struct TicketCashOutQuote {
    let canWithdraw: Bool
    let recoveryAmount: Int
    let recoveryRate: Double
    let blockedReason: TicketCashOutBlockedReason?
}

enum TicketCashOutBlockedReason {
    case alreadyWithdrawn
    case settled
    case missingKickoff
    case matchStarted
}

enum BettingRules {
    private static let fullRefundWindow: TimeInterval = 5 * 60
    private static let reducedRefundRate = 0.70

    static func combinedOdds(for selections: [BetSelection]) -> Double {
        selections.reduce(1.0) { $0 * $1.oddValue }
    }

    static func powerUpMultiplier(for selectedPowerUp: PowerUpType?) -> Double {
        selectedPowerUp == .multiplier ? 1.5 : 1.0
    }

    static func potentialPayout(
        stake: Int,
        selections: [BetSelection],
        selectedPowerUp: PowerUpType?
    ) -> Int {
        let totalOdds = combinedOdds(for: selections)
        let multiplier = powerUpMultiplier(for: selectedPowerUp)
        return Int((Double(stake) * totalOdds * multiplier).rounded())
    }

    static func potentialNetProfit(stake: Int, payout: Int) -> Int {
        max(payout - stake, 0)
    }

    static func normalizedStake(requestedStake: Int, availableBalance: Int) -> Int {
        min(max(requestedStake, 1), max(availableBalance, 0))
    }

    static func isStakeValid(stake: Int, availableBalance: Int) -> Bool {
        availableBalance > 0 && stake > 0 && stake <= availableBalance
    }

    static func hasReachedDailyLimit(currentDailyBets: Int, dailyBetLimit: Int) -> Bool {
        currentDailyBets >= dailyBetLimit
    }

    static func remainingDailyBets(currentDailyBets: Int, dailyBetLimit: Int) -> Int {
        max(dailyBetLimit - currentDailyBets, 0)
    }

    static func isLifelineSelectionCountValid(
        selectedPowerUp: PowerUpType?,
        selectionCount: Int
    ) -> Bool {
        selectedPowerUp != .lifeline || selectionCount >= 2
    }

    static func conflictingSelectionIds(_ selections: [BetSelection]) -> Set<UUID> {
        var groups: [UUID: [BetSelection]] = [:]
        for selection in selections {
            groups[selection.matchId, default: []].append(selection)
        }

        var conflicts = Set<UUID>()
        for (_, items) in groups where items.count > 1 {
            let latest = items.max { lhs, rhs in
                let leftDate = lhs.addedAt ?? .distantPast
                let rightDate = rhs.addedAt ?? .distantPast
                return leftDate < rightDate
            }
            if let latest {
                conflicts.insert(latest.id)
            }
        }
        return conflicts
    }

    static func canWithdraw(ticket: UserTicket, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        cashOutQuote(ticket: ticket, now: now, calendar: calendar).canWithdraw
    }

    static func cashOutQuote(
        ticket: UserTicket,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TicketCashOutQuote {
        if ticket.isWithdrawn {
            return TicketCashOutQuote(
                canWithdraw: false,
                recoveryAmount: ticket.withdrawalAmount ?? 0,
                recoveryRate: 0,
                blockedReason: .alreadyWithdrawn
            )
        }

        if ticket.isResultKnown {
            return TicketCashOutQuote(
                canWithdraw: false,
                recoveryAmount: 0,
                recoveryRate: 0,
                blockedReason: .settled
            )
        }

        let dates = ticket.selections.compactMap(\.startDate)
        guard dates.count == ticket.selections.count, let earliest = dates.min() else {
            return TicketCashOutQuote(
                canWithdraw: false,
                recoveryAmount: 0,
                recoveryRate: 0,
                blockedReason: .missingKickoff
            )
        }

        guard now < earliest else {
            return TicketCashOutQuote(
                canWithdraw: false,
                recoveryAmount: 0,
                recoveryRate: 0,
                blockedReason: .matchStarted
            )
        }

        let secondsSinceCreation = max(now.timeIntervalSince(ticket.date), 0)
        if secondsSinceCreation <= fullRefundWindow {
            return TicketCashOutQuote(
                canWithdraw: true,
                recoveryAmount: ticket.stake,
                recoveryRate: 1.0,
                blockedReason: nil
            )
        }

        let reducedAmount = max(Int((Double(ticket.stake) * reducedRefundRate).rounded(.down)), 1)
        return TicketCashOutQuote(
            canWithdraw: true,
            recoveryAmount: reducedAmount,
            recoveryRate: reducedRefundRate,
            blockedReason: nil
        )
    }

    static func shouldResetDailyBets(lastBetDate: String?, todayKey: String) -> Bool {
        lastBetDate != todayKey
    }

    static func winnerCode(from score: MatchScore) -> String? {
        guard let homeScore = score.homeScore, let awayScore = score.awayScore else { return nil }
        if homeScore > awayScore { return "1" }
        if awayScore > homeScore { return "2" }
        return "X"
    }

    static func selectionPickCode(_ label: String) -> String? {
        canonicalPickCode(from: label)
    }
}
