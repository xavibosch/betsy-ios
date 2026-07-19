import SwiftUI

struct LeagueHeaderView: View {
    let leagueName: String
    let lang: AppLang
    let topPadding: CGFloat
    let onChangeLeague: () -> Void

    private var resolvedLeagueName: String {
        leagueName.isEmpty ? "BETSY" : leagueName
    }

    init(
        leagueName: String,
        lang: AppLang,
        topPadding: CGFloat = 12,
        onChangeLeague: @escaping () -> Void
    ) {
        self.leagueName = leagueName
        self.lang = lang
        self.topPadding = topPadding
        self.onChangeLeague = onChangeLeague
    }

    var body: some View {
        VStack(spacing: 0) {
            BetsyScreenHeader(
                eyebrow: lang == .es ? "SELECCIONADA" : "SELECTED LEAGUE",
                title: resolvedLeagueName,
                subtitle: nil,
                tone: .dark
            ) {
                Button(action: onChangeLeague) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Theme.paper)
                        .frame(width: 44, height: 44)
                        .background(Theme.bg)
                        .overlay(
                            Rectangle()
                                .stroke(Theme.bg, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(lang == .es ? "Cambiar liga" : "Change league")
            }
            .padding(.top, topPadding)
            .padding(.bottom, 12)

            Rectangle()
                .fill(Theme.bg)
                .frame(height: 1)
        }
    }
}
