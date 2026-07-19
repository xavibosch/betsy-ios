import SwiftUI

enum BetsyCardTone {
    case light   // cream-white card — used in onboarding, modals, special surfaces
    case dark    // standard dark card — the default for in-app content

    var background: Color {
        switch self {
        case .light: return Theme.paper      // cream white
        case .dark:  return Theme.surface    // #141418 dark card
        }
    }

    var border: Color {
        switch self {
        case .light: return Color.black.opacity(0.08)
        case .dark:  return Theme.border     // white/8%
        }
    }

    var primaryText: Color {
        switch self {
        case .light: return Theme.bg         // near-black text on light cards
        case .dark:  return Theme.ink        // near-white text on dark cards
        }
    }

    var secondaryText: Color {
        switch self {
        case .light: return Theme.bg.opacity(0.58)
        case .dark:  return Theme.inkSecondary
        }
    }
}

struct BetsyCard<Content: View>: View {
    var tone: BetsyCardTone = .dark
    var backgroundColor: Color? = nil
    var padding: CGFloat = Theme.Spacing.md
    var radius: CGFloat = Theme.Radius.card
    var borderColor: Color? = nil
    @ViewBuilder let content: Content

    init(
        tone: BetsyCardTone = .dark,
        backgroundColor: Color? = nil,
        padding: CGFloat = Theme.Spacing.md,
        radius: CGFloat = Theme.Radius.card,
        borderColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.tone = tone
        self.backgroundColor = backgroundColor
        self.padding = padding
        self.radius = radius
        self.borderColor = borderColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(backgroundColor ?? tone.background)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius(radius), style: .continuous)
                .stroke(borderColor ?? tone.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius(radius), style: .continuous))
    }
}
