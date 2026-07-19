import SwiftUI

struct BetsyErrorStateView: View {
    let title: String
    let message: String
    var systemImage: String = "exclamationmark.triangle.fill"
    var retryTitle: String? = nil
    var retryAction: (() -> Void)? = nil

    // Betsy alert red — vivid, readable on white/paper
    private static let alertRed = Color(red: 0.86, green: 0.19, blue: 0.19)
    private static let alertRedDeep = Color(red: 0.56, green: 0.08, blue: 0.08)

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 38, height: 38)
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Self.alertRed)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if let retryTitle, let retryAction {
                Button(action: retryAction) {
                    Text(retryTitle)
                        .textCase(.uppercase)
                        .font(.system(size: 13, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(Self.alertRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .overlay(
                            Rectangle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Self.alertRed)
        .overlay(
            Rectangle()
                .stroke(Self.alertRedDeep, lineWidth: 2)
        )
    }
}
