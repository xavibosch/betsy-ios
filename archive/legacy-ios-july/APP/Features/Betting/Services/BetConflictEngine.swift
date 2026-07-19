import Foundation

/// A detected incompatibility between two selections of the same ticket.
struct BetConflict: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Both legs can never win together (e.g. Over 2.5 + Under 1.5). Blocks confirming.
        case contradiction
        /// One leg is implied by the other (e.g. Over 1.5 alongside Over 2.5). Warning only.
        case redundant
    }

    let id = UUID()
    let kind: Kind
    let selectionIds: [UUID]
    let messageES: String
    let messageEN: String

    func message(lang: AppLang) -> String { lang == .es ? messageES : messageEN }

    static func == (lhs: BetConflict, rhs: BetConflict) -> Bool {
        lhs.kind == rhs.kind && Set(lhs.selectionIds) == Set(rhs.selectionIds)
    }
}

/// Detects contradictions and redundancies between picks of the SAME match.
/// Picks on different matches never conflict.
enum BetConflictEngine {

    static func conflicts(in selections: [BetSelection]) -> [BetConflict] {
        var result: [BetConflict] = []
        let byMatch = Dictionary(grouping: selections) { "\($0.home.lowercased())|\($0.away.lowercased())" }
        for (_, picks) in byMatch where picks.count > 1 {
            result.append(contentsOf: conflictsWithinMatch(picks))
        }
        return result
    }

    static func hasContradiction(in selections: [BetSelection]) -> Bool {
        conflicts(in: selections).contains { $0.kind == .contradiction }
    }

    // MARK: - Normalised view of a pick

    private struct Leg {
        let selection: BetSelection
        let family: String        // totals / spreads / team_totals / h2h / btts / …
        let side: Side
        let point: Double?
        let qualifier: String?    // player or team (lowercased), nil = whole match

        var shortLabel: String { legLabel(selection) }
    }

    private enum Side: Equatable {
        case over, under, yes, no
        case code(String)         // "1" / "X" / "2"
        case other(String)
    }

    private static func normalizedFamily(_ key: String?) -> String {
        switch key ?? "h2h" {
        case "alternate_totals":      return "totals"
        case "alternate_spreads":     return "spreads"
        case "alternate_team_totals": return "team_totals"
        case "both_teams_to_score":   return "btts"
        default:                      return key ?? "h2h"
        }
    }

    private static func makeLeg(_ s: BetSelection) -> Leg {
        let family = normalizedFamily(s.marketKey)
        let rawSide = (s.pickSide ?? s.oddLabel).lowercased()
        let homeL = s.home.lowercased()
        let awayL = s.away.lowercased()

        let side: Side
        if rawSide.contains("over") { side = .over }
        else if rawSide.contains("under") { side = .under }
        else if rawSide.contains("yes") || rawSide == "sí" || rawSide == "si" { side = .yes }
        else if rawSide == "no" || rawSide.hasSuffix(" no") { side = .no }
        else if let code = canonicalPickCode(from: s.pickSide ?? s.oddLabel) { side = .code(code) }
        else { side = .other(rawSide) }

        var qualifier = s.participant?.lowercased()
        if qualifier == nil {
            // spreads / dnb name the team in the side string
            if rawSide.contains(homeL) { qualifier = homeL }
            else if rawSide.contains(awayL) { qualifier = awayL }
        }

        return Leg(selection: s, family: family, side: side, point: s.marketPoint, qualifier: qualifier)
    }

    // MARK: - Rules

    private static func conflictsWithinMatch(_ picks: [BetSelection]) -> [BetConflict] {
        let legs = picks.map(makeLeg)
        var found: [BetConflict] = []

        for i in 0..<legs.count {
            for j in (i + 1)..<legs.count {
                if let c = pairConflict(legs[i], legs[j]) { found.append(c) }
            }
        }
        return found
    }

    private static func pairConflict(_ a: Leg, _ b: Leg) -> BetConflict? {
        let sameFamily = a.family == b.family
        let sameQualifier = a.qualifier == b.qualifier

        // R2 — Over/Under impossible band on the same market+participant.
        if sameFamily, sameQualifier,
           let overLeg = legWithSide(.over, a, b), let underLeg = legWithSide(.under, a, b),
           let op = overLeg.point, let up = underLeg.point, op >= up {
            return contradiction(a, b,
                es: "\"\(a.shortLabel)\" y \"\(b.shortLabel)\" no pueden cumplirse a la vez.",
                en: "\"\(a.shortLabel)\" and \"\(b.shortLabel)\" can't both happen.")
        }

        // R1 — same direction, different lines: the easier one is already implied.
        if sameFamily, sameQualifier, a.side == b.side,
           let pa = a.point, let pb = b.point, pa != pb,
           a.side == .over || a.side == .under {
            let easier = easierLeg(a, b)
            return redundant(a, b,
                es: "\"\(easier.shortLabel)\" ya está incluida en la otra selección — elimina una.",
                en: "\"\(easier.shortLabel)\" is already covered by the other pick — remove one.")
        }

        // R5 — same-team handicaps: the softer line is implied by the harder one.
        if sameFamily, a.family == "spreads", sameQualifier, a.qualifier != nil,
           let pa = a.point, let pb = b.point, pa != pb {
            let easier = pa > pb ? a : b
            return redundant(a, b,
                es: "\"\(easier.shortLabel)\" ya está incluida en el otro hándicap — elimina una.",
                en: "\"\(easier.shortLabel)\" is already covered by the other handicap — remove one.")
        }

        // R3 — mutually exclusive one-shot markets.
        if sameFamily, a.side != b.side || !sameQualifier {
            switch a.family {
            case "h2h":
                if case .code = a.side, case .code = b.side, a.side != b.side {
                    return contradiction(a, b,
                        es: "Has elegido dos resultados distintos del mismo partido.",
                        en: "You picked two different results for the same match.")
                }
            case "btts":
                if (a.side == .yes && b.side == .no) || (a.side == .no && b.side == .yes) {
                    return contradiction(a, b,
                        es: "\"Ambos marcan: Sí\" y \"No\" son incompatibles.",
                        en: "\"Both teams to score: Yes\" and \"No\" are incompatible.")
                }
            case "draw_no_bet":
                if a.qualifier != b.qualifier, a.qualifier != nil, b.qualifier != nil {
                    return contradiction(a, b,
                        es: "Has elegido a los dos equipos en \"Empate no apuesta\".",
                        en: "You picked both teams in \"Draw no bet\".")
                }
            case "double_chance":
                return redundant(a, b,
                    es: "Dos dobles oportunidades del mismo partido se solapan — suele sobrar una.",
                    en: "Two double-chance picks on the same match overlap — one is usually unnecessary.")
            default:
                break
            }
        }

        // R4 — cross-market impossibilities around goals.
        if let c = crossGoalConflict(a, b) ?? crossGoalConflict(b, a) { return c }

        // R6 — winner pick vs double chance / draw-no-bet on the same match.
        if let c = crossResultConflict(a, b) ?? crossResultConflict(b, a) { return c }

        // R7 — both teams backed to win by a margin (negative handicaps on opposite teams).
        if a.family == "spreads", b.family == "spreads",
           a.qualifier != b.qualifier, a.qualifier != nil, b.qualifier != nil,
           let pa = a.point, let pb = b.point, pa < 0, pb < 0 {
            return contradiction(a, b,
                es: "Has apostado a que ganan los dos equipos con hándicap — imposible.",
                en: "You backed both teams to cover a negative handicap — impossible.")
        }

        return nil
    }

    /// Which result codes ("1"/"X"/"2") make this leg win. nil = not a result-style leg.
    private static func winningCodes(_ leg: Leg) -> Set<String>? {
        let s = leg.selection
        let raw = (s.pickSide ?? s.oddLabel).lowercased()
        let homeL = s.home.lowercased()
        let awayL = s.away.lowercased()
        switch leg.family {
        case "h2h":
            if case .code(let c) = leg.side { return [c] }
            return nil
        case "double_chance":
            var codes = Set<String>()
            if raw.contains(homeL) || raw.contains("home") || raw.contains("1") { codes.insert("1") }
            if raw.contains(awayL) || raw.contains("away") || raw.contains("2") { codes.insert("2") }
            if raw.contains("draw") || raw.contains("empate") { codes.insert("X") }
            return codes.isEmpty ? nil : codes
        case "draw_no_bet":
            // Draw is a push (settles as won here), so X always "survives".
            guard let q = leg.qualifier else { return nil }
            return q == homeL ? ["1", "X"] : ["2", "X"]
        default:
            return nil
        }
    }

    /// Winner pick vs double-chance/dnb logic, plus "no goals" vs a decisive result.
    private static func crossResultConflict(_ x: Leg, _ y: Leg) -> BetConflict? {
        // h2h / dc / dnb against each other: empty intersection = impossible together.
        if x.family != y.family,
           let xCodes = winningCodes(x), let yCodes = winningCodes(y) {
            if xCodes.isDisjoint(with: yCodes) {
                return contradiction(x, y,
                    es: "\"\(x.shortLabel)\" y \"\(y.shortLabel)\" apuntan a resultados opuestos del mismo partido.",
                    en: "\"\(x.shortLabel)\" and \"\(y.shortLabel)\" point to opposite results of the same match.")
            }
            // One result pick fully implies the other → the wider one adds nothing.
            if x.family == "h2h", xCodes.isSubset(of: yCodes) {
                return redundant(x, y,
                    es: "Si aciertas el ganador, \"\(y.shortLabel)\" ya está cubierta — sobra una.",
                    en: "If your winner pick hits, \"\(y.shortLabel)\" is already covered — one is unnecessary.")
            }
        }
        // "Under 0.5 goals" forces a 0-0 draw → any decisive winner pick is impossible.
        if x.family == "totals", x.side == .under, let p = x.point, p < 1,
           let yCodes = winningCodes(y), !yCodes.contains("X") {
            return contradiction(x, y,
                es: "\"Menos de \(String(format: "%g", p)) goles\" implica 0-0 — incompatible con un ganador.",
                en: "\"Under \(String(format: "%g", p)) goals\" means 0-0 — incompatible with a winner pick.")
        }
        return nil
    }

    /// Goal-logic contradictions across different markets.
    /// `x` is the "goals exist" side, `y` the "goals capped" side.
    private static func crossGoalConflict(_ x: Leg, _ y: Leg) -> BetConflict? {
        // BTTS Yes needs ≥2 goals (one each) → totals Under below 2 is impossible.
        if x.family == "btts", x.side == .yes,
           y.family == "totals", y.side == .under, let p = y.point, p < 2 {
            return contradiction(x, y,
                es: "\"Ambos marcan\" necesita al menos 2 goles — incompatible con \"\(y.shortLabel)\".",
                en: "\"Both teams to score\" needs at least 2 goals — incompatible with \"\(y.shortLabel)\".")
        }
        // BTTS Yes → every team scores → any team total Under 0.5 impossible.
        if x.family == "btts", x.side == .yes,
           y.family == "team_totals", y.side == .under, let p = y.point, p < 1 {
            return contradiction(x, y,
                es: "\"Ambos marcan\" es incompatible con dejar a un equipo sin goles.",
                en: "\"Both teams to score\" is incompatible with a team staying at zero goals.")
        }
        // Anytime scorer needs ≥1 goal → match total Under 0.5 impossible.
        if x.family == "player_goal_scorer_anytime",
           y.family == "totals", y.side == .under, let p = y.point, p < 1 {
            return contradiction(x, y,
                es: "Un goleador necesita que haya goles — incompatible con \"\(y.shortLabel)\".",
                en: "A goalscorer pick needs goals — incompatible with \"\(y.shortLabel)\".")
        }
        return nil
    }

    // MARK: - Small helpers

    private static func legWithSide(_ side: Side, _ a: Leg, _ b: Leg) -> Leg? {
        if a.side == side { return a }
        if b.side == side { return b }
        return nil
    }

    /// For same-direction O/U pairs: which leg is implied by the other.
    private static func easierLeg(_ a: Leg, _ b: Leg) -> Leg {
        guard let pa = a.point, let pb = b.point else { return a }
        switch a.side {
        case .over:  return pa < pb ? a : b    // lower Over line is easier
        case .under: return pa > pb ? a : b    // higher Under line is easier
        default:     return a
        }
    }

    private static func legLabel(_ s: BetSelection) -> String {
        var parts: [String] = []
        if let participant = s.participant { parts.append(participant) }
        if let side = s.pickSide, s.participant == nil || !side.lowercased().contains(s.participant!.lowercased()) {
            parts.append(side)
        }
        if let point = s.marketPoint { parts.append(String(format: "%.1f", point)) }
        let joined = parts.joined(separator: " ")
        return joined.isEmpty ? s.oddLabel : joined
    }

    private static func contradiction(_ a: Leg, _ b: Leg, es: String, en: String) -> BetConflict {
        BetConflict(kind: .contradiction, selectionIds: [a.selection.id, b.selection.id], messageES: es, messageEN: en)
    }

    private static func redundant(_ a: Leg, _ b: Leg, es: String, en: String) -> BetConflict {
        BetConflict(kind: .redundant, selectionIds: [a.selection.id, b.selection.id], messageES: es, messageEN: en)
    }
}
