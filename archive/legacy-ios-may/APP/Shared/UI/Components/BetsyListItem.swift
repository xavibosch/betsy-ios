import SwiftUI

struct BetsyListItem<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var detail: String? = nil
    var tone: BetsyCardTone = .light
    var statusColor: Color? = nil
    @ViewBuilder let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        tone: BetsyCardTone = .light,
        statusColor: Color? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.tone = tone
        self.statusColor = statusColor
        self.trailing = trailing()
    }

    var body: some View {
        BetsyCard(tone: tone, padding: 0, radius: Theme.Radius.control) {
            HStack(spacing: 0) {
                if let statusColor {
                    Rectangle()
                        .fill(statusColor)
                        .frame(width: 4)
                }

                HStack(alignment: .center, spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(title)
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(tone == .light ? Theme.bg : Theme.paper)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(tone == .light ? Theme.bg.opacity(0.70) : Color.white.opacity(0.76))
                        }

                        if let detail, !detail.isEmpty {
                            Text(detail.uppercased())
                                .font(.system(size: 11, weight: .black))
                                .tracking(0.8)
                                .foregroundStyle(tone == .light ? Theme.bg.opacity(0.66) : Color.white.opacity(0.72))
                        }
                    }

                    Spacer(minLength: 12)
                    trailing
                }
                .frame(minHeight: 72)
                .padding(Theme.Spacing.md)
            }
        }
    }
}
