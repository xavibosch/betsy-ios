import SwiftUI

struct ArenaStateBadgeView: View {
    let state: ArenaChallengeState
    let lang: AppLang

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: state.systemImage)
                .font(.system(size: 11, weight: .black))
                .accessibilityHidden(true)

            Text(state.label(lang: lang))
                .textCase(.uppercase)
                .font(.system(size: 11, weight: .black))
                .tracking(0.8)
        }
        .foregroundStyle(state.badgeForeground)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(state.badgeBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(state.prefersDarkSurface ? Color.white.opacity(0.18) : Theme.paperLine, lineWidth: 1)
        )
    }
}
