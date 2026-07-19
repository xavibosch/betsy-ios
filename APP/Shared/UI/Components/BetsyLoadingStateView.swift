import SwiftUI

struct BetsyLoadingStateView: View {
    let title: String
    var message: String? = nil

    var body: some View {
        BetsyContentCard {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(Theme.paper)
                    .scaleEffect(1.05)

                Text(title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if let message, !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.56))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
