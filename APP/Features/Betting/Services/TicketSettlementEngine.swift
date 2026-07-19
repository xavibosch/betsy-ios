import Foundation

struct TicketSettlementResult {
    let tickets: [UserTicket]
    let updatedPoints: Int
    let pointsDelta: Int
    let didChange: Bool
}

enum TicketSettlementEngine {
    static func simulate(
        tickets: [UserTicket],
        initialPoints: Int,
        referenceDate: Date = Date(),
        calendar: Calendar = .current,
        randomOutcome: ((BetSelection) -> Bool)? = nil
    ) -> TicketSettlementResult {
        var updated = tickets
        var points = initialPoints
        var delta = 0
        var didChange = false
        let resolver = randomOutcome ?? { simulatedOutcome(for: $0) }

        for index in updated.indices {
            if !updated[index].isResultKnown,
               shouldResolveDuringSimulation(updated[index], referenceDate: referenceDate, calendar: calendar) {
                let selectionResults = updated[index].selections.map(resolver)
                settle(ticket: &updated[index], selectionResults: selectionResults, points: &points, delta: &delta)
                didChange = true
            }
        }

        return TicketSettlementResult(
            tickets: updated,
            updatedPoints: points,
            pointsDelta: delta,
            didChange: didChange
        )
    }

    static func resolveWithScores(
        tickets: [UserTicket],
        initialPoints: Int,
        scoreByEventId: [String: MatchScore]
    ) -> TicketSettlementResult {
        var updated = tickets
        var points = initialPoints
        var delta = 0
        var didChange = false

        for index in updated.indices where !updated[index].isResultKnown {
            let selections = updated[index].selections
            guard !selections.isEmpty else { continue }

            var allCompleted = true
            var allResolvable = true
            var selectionResults: [Bool] = []

            for selection in selections {
                guard let score = scoreForSelection(selection, scoreByEventId: scoreByEventId) else {
                    allCompleted = false
                    break
                }
                guard score.completed else {
                    allCompleted = false
                    break
                }
                guard let expected = BettingRules.selectionPickCode(selection.oddLabel),
                      let actual = BettingRules.winnerCode(from: score) else {
                    allResolvable = false
                    break
                }

                selectionResults.append(expected == actual)
            }

            guard allCompleted, allResolvable else { continue }
            settle(ticket: &updated[index], selectionResults: selectionResults, points: &points, delta: &delta)
            didChange = true
        }

        return TicketSettlementResult(
            tickets: updated,
            updatedPoints: points,
            pointsDelta: delta,
            didChange: didChange
        )
    }

    private static func settle(
        ticket: inout UserTicket,
        selectionResults: [Bool],
        points: inout Int,
        delta: inout Int
    ) {
        let selections = ticket.selections
        let wins = zip(selections, selectionResults).filter { $0.1 }
        let losses = zip(selections, selectionResults).filter { !$0.1 }

        if losses.isEmpty {
            ticket.isResultKnown = true
            ticket.wasWon = true
            points += ticket.potentialPayout
            delta += ticket.potentialPayout
            return
        }

        if ticket.appliedPowerUp == .lifeline,
           !ticket.lifelineConsumed,
           selections.count > 1 {
            let unitStake = Double(ticket.stake) / Double(max(selections.count, 1))
            let recovered = wins.reduce(0) { partial, pair in
                partial + Int((unitStake * pair.0.oddValue).rounded())
            }
            ticket.lifelineConsumed = true
            ticket.isResultKnown = true
            ticket.wasWon = recovered >= ticket.stake
            if recovered != 0 {
                points += recovered
                delta += recovered
            }
            return
        }

        ticket.isResultKnown = true
        ticket.wasWon = false
    }

    private static func scoreForSelection(
        _ selection: BetSelection,
        scoreByEventId: [String: MatchScore]
    ) -> MatchScore? {
        if let eventId = selection.eventId,
           let score = scoreByEventId[eventId] {
            return score
        }

        return scoreByEventId.values.first {
            $0.home.lowercased() == selection.home.lowercased()
                && $0.away.lowercased() == selection.away.lowercased()
        }
    }

    private static func shouldResolveDuringSimulation(
        _ ticket: UserTicket,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        let selections = ticket.selections
        guard !selections.isEmpty else { return false }

        let kickoffDates = selections.compactMap(\.startDate)
        if kickoffDates.count == selections.count {
            return kickoffDates.allSatisfy { $0 <= referenceDate }
        }

        let startOfReferenceDay = calendar.startOfDay(for: referenceDate)
        return ticket.date < startOfReferenceDay
    }

    private static func simulatedOutcome(for selection: BetSelection) -> Bool {
        let identifier = [
            selection.eventId ?? "",
            selection.home.lowercased(),
            selection.away.lowercased(),
            selection.oddLabel.lowercased(),
            String(format: "%.3f", selection.oddValue)
        ]
        .joined(separator: "|")

        let hash = stableHash(identifier)
        let normalized = Double(hash % 10_000) / 10_000.0
        let impliedProbability = max(0.18, min(0.82, 1.0 / max(selection.oddValue, 1.01)))
        return normalized <= impliedProbability
    }

    private static func stableHash(_ string: String) -> Int {
        string.utf8.reduce(5381) { partial, byte in
            ((partial << 5) &+ partial) &+ Int(byte)
        }
    }
}
