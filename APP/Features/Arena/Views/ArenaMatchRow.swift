import SwiftUI
import UIKit

struct ArenaMatchRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let match: ArenaMatch
    @Binding var selections: [ArenaBetSelection]
    let isLocked: Bool
    let lang: AppLang
    var singleSelectionAcrossMatches: Bool = false
    var accent: Color = Theme.electric

    private var dateText: String? {
        guard let startDate = match.startDate else { return nil }
        return localizedDateString(startDate, format: "dd MMM • HH:mm", lang: lang)
    }

    private var selectedSelection: ArenaBetSelection? {
        selections.first(where: { $0.matchId == match.id })
    }

    private var hasPick: Bool { selectedSelection != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(accent)
                            .frame(width: 6, height: 6)
                        Text(match.league)
                            .textCase(.uppercase)
                            .font(.system(size: 12, weight: .black))
                            .tracking(0.9)
                            .foregroundStyle(accent)
                    }

                    Text(match.home)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Theme.ink)

                    Text(match.away)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Theme.inkSecondary)

                    if let dateText {
                        Text(dateText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }

                Spacer()

                Text("1X2")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: accent.opacity(0.35), radius: 6, x: 0, y: 3)
            }

            HStack(spacing: 8) {
                ForEach(match.odds) { odd in
                    let isSelected = selections.contains(where: { $0.matchId == match.id && $0.oddLabel == odd.label })
                    let label = readableOddLabel(odd.label, home: match.home, away: match.away, lang: lang)

                    Button {
                        guard !isLocked else { return }
                        UIImpactFeedbackGenerator(style: isSelected ? .soft : .medium).impactOccurred()
                        if isSelected {
                            selections.removeAll(where: { $0.matchId == match.id && $0.oddLabel == odd.label })
                        } else {
                            let nextSelection = ArenaBetSelection(
                                matchId: match.id,
                                home: match.home,
                                away: match.away,
                                oddLabel: odd.label,
                                oddValue: odd.value
                            )

                            if singleSelectionAcrossMatches {
                                selections = [nextSelection]
                            } else {
                                selections.removeAll(where: { $0.matchId == match.id })
                                selections.append(nextSelection)
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(label)
                                .font(.system(size: 11, weight: .black))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("x\(String(format: "%.2f", odd.value))")
                                .font(.system(size: 16, weight: .black))
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(
                            Group {
                                if isSelected {
                                    LinearGradient(
                                        colors: [accent, accent.opacity(0.75)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    Theme.surfaceAlt
                                }
                            }
                        )
                        .foregroundStyle(isSelected ? Color.white : Theme.ink)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    isSelected ? Color.clear : Theme.border,
                                    lineWidth: 1.5
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .scaleEffect(!reduceMotion && isSelected ? 1.03 : 1.0)
                        .shadow(color: isSelected ? accent.opacity(0.45) : Color.clear, radius: isSelected ? 10 : 0, x: 0, y: 4)
                        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.68), value: isSelected)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                }
            }

            if let selectedSelection {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(accent)
                        .accessibilityHidden(true)
                    Text(
                        (lang == .es ? "Tu pick: " : "Your pick: ")
                        + readableOddLabel(
                            selectedSelection.oddLabel,
                            home: selectedSelection.home,
                            away: selectedSelection.away,
                            lang: lang
                        )
                        + " @ x\(String(format: "%.2f", selectedSelection.oddValue))"
                    )
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    hasPick ? accent.opacity(0.55) : Theme.border,
                    lineWidth: hasPick ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: hasPick ? accent.opacity(0.16) : Color.black.opacity(0.08), radius: hasPick ? 12 : 6, x: 0, y: 4)
    }
}
