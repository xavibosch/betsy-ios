import SwiftUI
import UIKit

struct MatchRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let match: Match
    let score: MatchScore?
    let lang: AppLang
    @Binding var selections: [BetSelection]
    var challengeMode: Bool = false
    var onChallengeSelect: ((Odd) -> Void)? = nil
    var onOpenDetails: (() -> Void)? = nil

    private var dateTimeText: String {
        guard let date = match.startDate else { return lang == .es ? "Hora por definir" : "Time TBD" }
        return localizedDateString(date, format: "dd MMM • HH:mm", lang: lang)
    }

    private var orderedOdds: [Odd] {
        let indexed = Array(match.odds.enumerated())
        let sorted = indexed.sorted { lhs, rhs in
            let left = oddRank(for: lhs.element)
            let right = oddRank(for: rhs.element)
            if left == right { return lhs.offset < rhs.offset }
            return left < right
        }.map(\.element)

        let hasKnownPick = sorted.contains { oddPickCode(for: $0) != nil }
        return hasKnownPick ? sorted : match.odds
    }

    private var totalMarketCount: Int {
        match.markets.count
    }

    private var scoreText: String? {
        guard let score else { return nil }
        guard let home = score.homeScore, let away = score.awayScore else { return nil }
        return "\(home) - \(away)"
    }

    private func abbreviatedTeam(_ name: String) -> String {
        if name.count <= 16 { return name }
        let words = name.split(separator: " ").map(String.init)
        if words.count >= 2 {
            return words.prefix(3).compactMap { $0.first }.map { String($0).uppercased() }.joined()
        }
        return String(name.prefix(3)).uppercased()
    }

    private func oddPickCode(for odd: Odd) -> String? {
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
        switch oddPickCode(for: odd) {
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

    private func oddButtonTitle(_ odd: Odd) -> String {
        switch oddPickCode(for: odd) {
        case "1":
            return abbreviatedTeam(match.home)
        case "2":
            return abbreviatedTeam(match.away)
        case "X":
            return "X"
        default:
            return odd.label
        }
    }

    private func selectionLabel(for odd: Odd) -> String {
        guard let marketKey = odd.marketKey, marketKey != "h2h" else {
            return odd.label
        }
        let marketName = odd.marketName ?? marketKey
        if let point = odd.point {
            return "\(marketName) · \(odd.label) (\(String(format: "%.1f", point)))"
        }
        return "\(marketName) · \(odd.label)"
    }

    var body: some View {
        BetsyCard(tone: .light, padding: 14, radius: 0, borderColor: Theme.paperLine) {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Text(match.league)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Theme.bg.opacity(0.72))

                    Spacer()

                    Text(dateTimeText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.bg.opacity(0.72))

                    if scoreText != nil {
                        let isCompleted = score?.completed ?? false
                        Text(isCompleted ? "FT" : "LIVE")
                            .font(.system(size: 11, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.06))
                            .foregroundStyle(isCompleted ? Theme.bg.opacity(0.76) : Color.red.opacity(0.92))
                    }
                }

                HStack(alignment: .center, spacing: 10) {
                    Text(match.home)
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(Theme.bg)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("VS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Theme.paper)
                            .tracking(1.5)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.bg.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        if let scoreText {
                            Text(scoreText)
                                .font(.caption2.bold())
                                .foregroundStyle(Theme.bg.opacity(0.66))
                        }
                    }
                    .accessibilityHidden(true)

                    Text(match.away)
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(Theme.bg)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(match.home) \(lang == .es ? "contra" : "vs") \(match.away)\(scoreText != nil ? ", \(scoreText!)" : "")")
                .accessibilityHint(lang == .es ? "Doble toque para ver mercados" : "Double tap to view markets")
                .accessibilityAddTraits(.isButton)
                .contentShape(Rectangle())
                .onTapGesture {
                    onOpenDetails?()
                }

                HStack(spacing: 8) {
                    ForEach(orderedOdds) { odd in
                        let selectionLabel = selectionLabel(for: odd)
                        let isSelected = !challengeMode && selections.contains(where: { $0.matchId == match.id && $0.oddLabel == selectionLabel })
                        let isLocked = challengeMode && odd.value < 2.5

                        Button {
                            if challengeMode {
                                if isLocked {
                                    onChallengeSelect?(odd)
                                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                    return
                                }
                                onChallengeSelect?(odd)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                return
                            }
                            if isSelected {
                                selections.removeAll(where: { $0.matchId == match.id && $0.oddLabel == selectionLabel })
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } else {
                                let selection = BetSelection(
                                    matchId: match.id,
                                    eventId: match.eventId,
                                    sportKey: match.sportKey,
                                    home: match.home,
                                    away: match.away,
                                    league: match.league,
                                    startDate: match.startDate,
                                    oddLabel: selectionLabel,
                                    oddValue: odd.value,
                                    addedAt: Date()
                                )
                                selections.append(selection)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(oddPickCode(for: odd) ?? oddButtonTitle(odd))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(isSelected ? Theme.paper.opacity(0.94) : Theme.bg.opacity(0.74))
                                Text(String(format: "%.2f", odd.value))
                                    .font(.system(size: 18, weight: .black))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(isSelected ? Theme.bg : Theme.paper)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0, style: .continuous)
                                    .stroke(isSelected ? Theme.bg : Theme.paperLine, lineWidth: isSelected ? 0 : 1)
                            )
                            .foregroundStyle(isSelected ? Theme.paper : Theme.bg)
                            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.7), value: isSelected)
                        }
                        .buttonStyle(.plain)
                        .opacity(isLocked ? 0.35 : 1)
                        .accessibilityLabel("\(readableOddLabel(selectionLabel, home: match.home, away: match.away, lang: lang)), cuota \(String(format: "%.2f", odd.value))")
                        .accessibilityHint(isLocked
                            ? (lang == .es ? "Cuota bloqueada para este reto" : "Odds locked for this challenge")
                            : (isSelected
                                ? (lang == .es ? "Seleccionado. Doble toque para quitar" : "Selected. Double tap to remove")
                                : (lang == .es ? "Doble toque para seleccionar" : "Double tap to select")))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }

                Button {
                    onOpenDetails?()
                } label: {
                    HStack {
                        Text(lang == .es ? "Ver +\(max(totalMarketCount - 1, 0)) mercados" : "View +\(max(totalMarketCount - 1, 0)) markets")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Theme.bg.opacity(0.74))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(lang == .es ? "Ver todos los mercados de \(match.home) contra \(match.away)" : "View all markets for \(match.home) versus \(match.away)")
            }
        }
        .accessibilityElement(children: .contain)
    }
}
