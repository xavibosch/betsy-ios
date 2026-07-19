import SwiftUI

struct BetsyStatBlock: View {
    let title: String
    let value: String
    var detail: String? = nil
    var systemImage: String? = nil
    var tone: BetsyCardTone = .light
    var accent: Color = Theme.bg

    var body: some View {
        BetsyCard(tone: tone, padding: Theme.Spacing.md, radius: Theme.Radius.control, borderColor: tone == .light ? Theme.paperLine : Theme.border) {
            HStack(spacing: Theme.Spacing.xxs) {
                if let systemImage, !systemImage.isEmpty {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .bold))
                }

                Text(title)
                    .textCase(.uppercase)
                    .font(Theme.Typography.eyebrow)
                    .tracking(0.8)
            }
            .foregroundStyle(tone == .light ? Theme.bg.opacity(0.80) : Color.white.opacity(0.72))

            Text(value)
                .font(Theme.Typography.statValue)
                .tracking(-0.4)
                .foregroundStyle(tone == .light ? accent : Theme.paper)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tone == .light ? Theme.bg.opacity(0.70) : Color.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
