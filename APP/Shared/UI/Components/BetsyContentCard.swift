import SwiftUI

struct BetsyContentCard<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.md
    var radius: CGFloat = Theme.Radius.card
    var tint: Color = Theme.card
    var border: Color = Theme.bg
    @ViewBuilder let content: Content

    init(
        padding: CGFloat = Theme.Spacing.md,
        radius: CGFloat = Theme.Radius.card,
        tint: Color = Theme.card,
        border: Color = Theme.bg,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.radius = radius
        self.tint = tint
        self.border = border
        self.content = content()
    }

    var body: some View {
        BetsyCard(
            tone: .dark,
            backgroundColor: tint,
            padding: padding,
            radius: radius,
            borderColor: border
        ) {
            content
        }
    }
}
