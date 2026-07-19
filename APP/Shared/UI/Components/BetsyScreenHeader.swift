import SwiftUI

enum BetsyTextTone {
    case light
    case dark

    var primary: Color {
        switch self {
        case .light: return Theme.textMain
        case .dark: return Theme.bg
        }
    }

    var secondary: Color {
        switch self {
        case .light: return Theme.textSecondary
        case .dark: return Theme.bg.opacity(0.62)
        }
    }

    var eyebrow: Color {
        switch self {
        case .light: return Color.white.opacity(0.46)
        case .dark: return Theme.bg.opacity(0.92)
        }
    }
}

struct BetsyScreenHeader<Accessory: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let tone: BetsyTextTone
    @ViewBuilder let accessory: Accessory

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        tone: BetsyTextTone = .light,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.accessory = accessory()
    }

    var body: some View {
        BetsyHeader(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            tone: tone
        ) {
            accessory
        }
    }
}
