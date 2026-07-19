import SwiftUI

struct ArenaInviteView: View {
    let duel: ArenaDuel
    @ObservedObject var leagueService: LeagueService
    let lang: AppLang
    var currentUserAvatarImageData: Data? = nil
    let onAccept: () -> Void
    let onDecline: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var challengeMatch: ArenaMatch? {
        duel.matches.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.mainBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        inviteHeader

                        ArenaIncomingChallengeSurface(
                            duel: duel,
                            lang: lang,
                            onAccept: {
                                leagueService.acceptArena(duelId: duel.id, leagueId: duel.leagueId) { success in
                                    if success {
                                        onAccept()
                                        dismiss()
                                    }
                                }
                            },
                            onReject: {
                                leagueService.declineArena(duelId: duel.id, leagueId: duel.leagueId)
                                onDecline()
                                dismiss()
                            }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var inviteHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lang == .es ? "SELECCIONADA" : "SELECTED LEAGUE")
                        .font(.system(size: 11, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(Theme.bg.opacity(0.58))

                    Text(challengeMatch?.league ?? "BETSY")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Theme.bg)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Theme.bg)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Theme.bg, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cerrar")
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)

            Rectangle()
                .fill(Theme.bg)
                .frame(height: 1)
        }
    }
}
