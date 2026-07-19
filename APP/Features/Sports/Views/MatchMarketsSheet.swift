import SwiftUI
import UIKit

struct MatchMarketsSheet: View {
    let match: Match
    let score: MatchScore?
    @Binding var selections: [BetSelection]
    var challengeMode: Bool = false
    var onChallengeSelect: ((Odd) -> Void)? = nil
    let lang: AppLang
    @Environment(\.dismiss) private var dismiss

    private var sortedMarkets: [BetMarket] {
        match.markets.sorted { a, b in
            if a.key == "h2h" { return true }
            if b.key == "h2h" { return false }
            return a.name < b.name
        }
    }

    private var dateText: String {
        guard let date = match.startDate else { return lang == .es ? "Hora por definir" : "Kickoff TBA" }
        return localizedDateString(date, format: "EEEE d MMM, HH:mm", lang: lang)
    }

    private var scoreText: String? {
        guard let score else { return nil }
        guard let home = score.homeScore, let away = score.awayScore else { return nil }
        return "\(home) - \(away)"
    }

    private func oddLabel(_ odd: Odd) -> String {
        if let point = odd.point {
            return "\(odd.label) (\(String(format: "%.1f", point)))"
        }
        return odd.label
    }

    private func marketPickCode(for odd: Odd) -> String? {
        if let code = canonicalPickCode(from: odd.label) {
            return code
        }
        let normalized = odd.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == match.home.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            return "1"
        }
        if normalized == match.away.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            return "2"
        }
        return nil
    }

    private func oddRank(for odd: Odd) -> Int {
        switch marketPickCode(for: odd) {
        case "1":
            return 0
        case "X":
            return 1
        case "2":
            return 2
        default:
            return 3
        }
    }

    private func orderedOutcomes(for market: BetMarket) -> [Odd] {
        guard market.key == "h2h" else { return market.outcomes }
        let indexed = Array(market.outcomes.enumerated())
        let sorted = indexed.sorted { lhs, rhs in
            let left = oddRank(for: lhs.element)
            let right = oddRank(for: rhs.element)
            if left == right { return lhs.offset < rhs.offset }
            return left < right
        }.map(\.element)
        let hasKnownPick = sorted.contains { marketPickCode(for: $0) != nil }
        return hasKnownPick ? sorted : market.outcomes
    }

    private func oddDisplayText(_ odd: Odd) -> String {
        let key = odd.marketKey ?? "h2h"
        guard key == "h2h" else { return oddLabel(odd) }
        switch marketPickCode(for: odd) {
        case "1":
            return match.home
        case "2":
            return match.away
        case "X":
            return lang == .es ? "Empate" : "Draw"
        default:
            return oddLabel(odd)
        }
    }

    private func ticketLabel(for odd: Odd) -> String {
        guard let marketKey = odd.marketKey, marketKey != "h2h" else {
            return oddLabel(odd)
        }
        let marketName = odd.marketName ?? marketKey
        return "\(marketName) · \(oddLabel(odd))"
    }

    private func teamAbbreviation(_ name: String) -> String {
        let words = name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let initials = words.prefix(3).map { String($0.prefix(1)) }.joined()
        if initials.count >= 2 { return initials.uppercased() }
        return String(name.prefix(3)).uppercased()
    }

    private func teamColor(_ seed: String) -> Color {
        let palette: [Color] = [
            Color(red: 0.34, green: 0.16, blue: 0.63),
            Color(red: 0.00, green: 0.48, blue: 0.20),
            Color(red: 0.96, green: 0.70, blue: 0.06),
            Color(red: 0.64, green: 0.00, blue: 0.27),
            Color(red: 0.42, green: 0.67, blue: 0.87),
            Color(red: 0.93, green: 0.01, blue: 0.03)
        ]
        let value = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[value % palette.count]
    }

    private func teamBadge(_ name: String) -> some View {
        Text(teamAbbreviation(name))
            .font(.system(size: 17, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 58, height: 58)
            .background(teamColor(name))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }

    private var matchHeroCard: some View {
        VStack(spacing: 18) {
            HStack {
                Text(match.league)
                    .textCase(.uppercase)
                    .font(.system(size: 12, weight: .black))
                    .tracking(1.6)
                    .foregroundStyle(Color.white.opacity(0.72))
                Spacer()
                if let scoreText {
                    let isCompleted = score?.completed ?? false
                    Text(isCompleted ? "FT \(scoreText)" : "LIVE \(scoreText)")
                        .font(.system(size: 11, weight: .black))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(isCompleted ? Color.white.opacity(0.08) : Theme.hot.opacity(0.18))
                        .foregroundStyle(isCompleted ? Color.white.opacity(0.72) : Theme.hot)
                        .clipShape(Capsule())
                }
            }

            HStack(alignment: .center, spacing: 18) {
                VStack(spacing: 8) {
                    teamBadge(match.home)
                    Text(match.home)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("1-2-4")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text(lang == .es ? "VS" : "VS")
                        .font(.system(size: 12, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Color.white.opacity(0.7))
                    Text(match.startDate.map { localizedDateString($0, format: "HH:mm", lang: lang) } ?? "--:--")
                        .font(.system(size: 28, weight: .black))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.opacity(0.72))
                    Text(dateText)
                        .textCase(.uppercase)
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    teamBadge(match.away)
                    Text(match.away)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("1-4-2")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }

            if challengeMode {
                Text(lang == .es ? "MODO RETO · elige una cuota válida para Arena" : "CHALLENGE MODE · choose a valid Arena pick")
                    .font(.system(size: 12, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Theme.surfaceAlt, Theme.surface, Color(red: 0.03, green: 0.07, blue: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.paperLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        matchHeroCard

                        if sortedMarkets.isEmpty {
                            Text(lang == .es ? "No hay mercados extra para este partido." : "No extra markets available for this match.")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.78))
                                .padding(18)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .glassSurface(radius: 18, tint: Theme.card.opacity(0.76), border: Theme.paperLine)
                        } else {
                            ForEach(sortedMarkets) { market in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(market.name)
                                            .font(.system(size: 11, weight: .black))
                                            .tracking(1.6)
                                            .foregroundStyle(Color.white.opacity(0.72))
                                        Spacer()
                                        if market.outcomes.count > 2 {
                                            Text("+\(market.outcomes.count) mercados")
                                                .font(.system(size: 12, weight: .black))
                                                .foregroundStyle(Color.white.opacity(0.78))
                                        }
                                    }

                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                        ForEach(orderedOutcomes(for: market)) { odd in
                                            let label = ticketLabel(for: odd)
                                            let isSelected = !challengeMode && selections.contains(where: { $0.matchId == match.id && $0.oddLabel == label })
                                            let isLocked = challengeMode && odd.value < 2.5

                                            Button {
                                                if challengeMode {
                                                    guard !isLocked else { return }
                                                    onChallengeSelect?(odd)
                                                    dismiss()
                                                    return
                                                }
                                                if isSelected {
                                                    selections.removeAll(where: { $0.matchId == match.id && $0.oddLabel == label })
                                                } else {
                                                    selections.append(
                                                        BetSelection(
                                                            matchId: match.id,
                                                            eventId: match.eventId,
                                                            sportKey: match.sportKey,
                                                            home: match.home,
                                                            away: match.away,
                                                            league: match.league,
                                                            startDate: match.startDate,
                                                            oddLabel: label,
                                                            oddValue: odd.value,
                                                            addedAt: Date()
                                                        )
                                                    )
                                                }
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            } label: {
                                                VStack(spacing: 4) {
                                                    Text(oddDisplayText(odd))
                                                        .font(.system(size: 11, weight: .black))
                                                        .tracking(0.4)
                                                        .lineLimit(2)
                                                        .multilineTextAlignment(.center)
                                                    Text(String(format: "%.2f", odd.value))
                                                        .font(.system(size: 20, weight: .black))
                                                        .monospacedDigit()
                                                }
                                                .frame(maxWidth: .infinity, minHeight: 72)
                                                .padding(.horizontal, 8)
                                                .background(isSelected ? Theme.paper : Theme.surfaceAlt)
                                                .foregroundStyle(isSelected ? Theme.bg : .white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .stroke(isSelected ? Theme.paper : Theme.paperLine, lineWidth: 1)
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            }
                                            .opacity(isLocked ? 0.35 : 1)
                                            .disabled(isLocked)
                                            .accessibilityLabel("\(oddDisplayText(odd)), cuota \(String(format: "%.2f", odd.value))")
                                            .accessibilityHint(isLocked ? "Cuota no válida para Arena" : (isSelected ? "Seleccionado. Doble toque para quitar" : "Doble toque para seleccionar"))
                                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                                        }
                                    }
                                }
                                .padding(16)
                                .background(Theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Theme.paperLine, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(lang == .es ? "Mercados del partido" : "Match markets")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang == .es ? "Cerrar" : "Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
