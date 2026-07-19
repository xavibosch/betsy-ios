import SwiftUI

struct BetsyHeader<Accessory: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    var tone: BetsyTextTone = .light
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
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if let eyebrow, !eyebrow.isEmpty {
                    Text(eyebrow)
                        .textCase(.uppercase)
                        .font(Theme.Typography.eyebrow)
                        .tracking(1.2)
                        .foregroundStyle(tone.eyebrow)
                }

                Text(title)
                    .font(Theme.Typography.screenTitle)
                    .tracking(-0.3)
                    .foregroundStyle(tone.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.Typography.body)
                        .foregroundStyle(tone.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
            accessory
        }
    }
}
