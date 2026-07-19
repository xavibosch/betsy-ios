import SwiftUI
import UIKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: — Button styles
// ─────────────────────────────────────────────────────────────────────────────

enum BetsyButtonStyle {
    case primary     // ★ Electric-lime fill · black ink — the Betsy signature CTA
    case secondary   // Dark surface · ink text — standard action
    case destructive // Red tint
    case hero        // Electric-indigo gradient — hero moments
    case arena       // Hot-red gradient — Arena duels / urgency
    case win         // Lime-green gradient — positive confirms
    case ghost       // No fill, accent border + text — subtle

    var usesGradient: Bool {
        switch self { case .hero, .arena, .win: return true; default: return false }
    }

    @ViewBuilder
    var gradient: some View {
        switch self {
        case .hero:  Theme.heroGradient
        case .arena: Theme.arenaGradient
        case .win:   Theme.winGradient
        default:     Color.clear
        }
    }

    var background: Color {
        switch self {
        case .primary:     return Theme.accent          // lime #d4ff3a
        case .secondary:   return Theme.surfaceAlt      // dark surface
        case .destructive: return Color(red: 0.78, green: 0.10, blue: 0.12).opacity(0.22)
        case .ghost:       return Color.clear
        default:           return Color.clear
        }
    }

    var foreground: Color {
        switch self {
        case .primary:     return Theme.accentInk       // near-black on lime
        case .secondary:   return Theme.ink             // near-white
        case .destructive: return Color(red: 0.96, green: 0.27, blue: 0.27)
        case .ghost:       return Theme.accent
        case .hero, .arena, .win: return Color.white
        }
    }

    var border: Color {
        switch self {
        case .primary:     return Theme.accentLine
        case .secondary:   return Theme.border
        case .destructive: return Color(red: 0.96, green: 0.27, blue: 0.27).opacity(0.36)
        case .ghost:       return Theme.accentLine
        case .hero:        return Color.clear
        case .arena:       return Color.clear
        case .win:         return Color.clear
        }
    }

    var glow: Color {
        switch self {
        case .primary:     return Theme.accent.opacity(0.40)
        case .hero:        return Theme.electric.opacity(0.38)
        case .arena:       return Theme.hot.opacity(0.38)
        case .win:         return Theme.lime.opacity(0.32)
        default:           return Color.clear
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: — Press animation
// ─────────────────────────────────────────────────────────────────────────────

private struct BetsyPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var isDisabled: Bool
    var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed && !isDisabled ? 0.96 : 1.0)
            .opacity(configuration.isPressed && !isDisabled ? 0.88 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                guard pressed, !isDisabled else { return }
                UIImpactFeedbackGenerator(style: hapticStyle).impactOccurred()
            }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: — BetsyButton
// ─────────────────────────────────────────────────────────────────────────────

struct BetsyButton: View {
    let title: String
    var systemImage: String? = nil
    var style: BetsyButtonStyle = .primary
    var isDisabled: Bool = false
    var fillsWidth: Bool = true
    var action: () -> Void

    private var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch style {
        case .primary:       return .medium
        case .hero, .arena:  return .heavy
        case .win:           return .rigid
        default:             return .light
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                }
                Text(title)
                    .font(Theme.Typography.button)
                    .tracking(0.4)
                    .lineLimit(1)
            }
            .foregroundStyle(style.foreground.opacity(isDisabled ? 0.40 : 1))
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(height: 50)
            .padding(.horizontal, fillsWidth ? 0 : Theme.Spacing.md)
            .background(
                Group {
                    if style.usesGradient {
                        style.gradient.opacity(isDisabled ? 0.40 : 1)
                    } else {
                        style.background.opacity(isDisabled ? 0.40 : 1)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .stroke(style.border.opacity(isDisabled ? 0.28 : 1), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .shadow(
                color: isDisabled ? Color.clear : style.glow,
                radius: 12, x: 0, y: 5
            )
        }
        .buttonStyle(BetsyPressButtonStyle(isDisabled: isDisabled, hapticStyle: hapticStyle))
        .disabled(isDisabled)
    }
}
