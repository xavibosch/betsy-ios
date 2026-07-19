import SwiftUI

struct BetsyEmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "square.stack.3d.up.slash"

    var body: some View {
        BetsyContentCard {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.paper)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
