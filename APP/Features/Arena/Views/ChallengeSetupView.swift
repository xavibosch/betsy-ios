import SwiftUI

struct ChallengeSetupView: View {
    let leagueName: String
    let members: [LeagueMember]
    let isLoading: Bool
    let errorMessage: String?
    let lang: AppLang
    var currentUserId: String? = nil
    var currentUserAvatarImageData: Data? = nil
    let onReload: () -> Void
    let onSelectMember: (LeagueMember) -> Void

    @Environment(\.dismiss) private var dismiss

    private var availableMembers: [LeagueMember] {
        members.sorted { lhs, rhs in
            if lhs.points == rhs.points {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.points > rhs.points
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        BetsyScreenHeader(
                            eyebrow: lang == .es ? "Nuevo reto" : "New challenge",
                            title: leagueName,
                            subtitle: lang == .es
                                ? "Elige a quién vas a retar. Después fijaremos la apuesta y Arena asignará los partidos para el pick."
                                : "Choose who you want to challenge. Next we will set the stake and Arena will assign the matches for the pick.",
                            tone: .dark
                        )

                        BetsyCard(tone: .dark, backgroundColor: Theme.surface, padding: 14, radius: 18, borderColor: Theme.border) {
                            HStack(spacing: 10) {
                                challengeStepPill(title: lang == .es ? "1. Rival" : "1. Opponent")
                                challengeStepPill(title: lang == .es ? "2. Apuesta" : "2. Stake")
                                challengeStepPill(title: lang == .es ? "3. Pick" : "3. Pick")
                            }
                        }

                        if !availableMembers.isEmpty {
                            Text(
                                lang == .es
                                    ? "\(availableMembers.count) rivales disponibles en esta liga"
                                    : "\(availableMembers.count) opponents available in this league"
                            )
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.inkSecondary)
                        }

                        if let errorMessage, !errorMessage.isEmpty {
                            BetsyErrorStateView(
                                title: lang == .es ? "No pudimos cargar rivales" : "Unable to load opponents",
                                message: errorMessage,
                                retryTitle: lang == .es ? "Reintentar" : "Retry",
                                retryAction: onReload
                            )
                        } else if isLoading {
                            BetsyLoadingStateView(
                                title: lang == .es ? "Cargando miembros..." : "Loading members...",
                                message: lang == .es
                                    ? "Estamos preparando la lista de rivales."
                                    : "Preparing the opponent list."
                            )
                        } else if availableMembers.isEmpty {
                            BetsyEmptyStateView(
                                title: lang == .es ? "No hay rivales disponibles" : "No opponents available",
                                message: lang == .es
                                    ? "Comparte la liga o recarga miembros para empezar un reto."
                                    : "Share the league or reload members to start a challenge.",
                                systemImage: "person.2.slash"
                            )

                            BetsyButton(
                                title: lang == .es ? "Recargar miembros" : "Reload members",
                                style: .secondary
                            ) {
                                onReload()
                            }
                        } else {
                            ForEach(availableMembers) { member in
                                Button {
                                    onSelectMember(member)
                                } label: {
                                    BetsyCard(tone: .dark, backgroundColor: Theme.surface, padding: 16, radius: 16, borderColor: Theme.border) {
                                        HStack(spacing: 12) {
                                            BetsyAvatarView(
                                                imageData: member.id == currentUserId ? currentUserAvatarImageData : nil,
                                                name: member.name,
                                                size: 34,
                                                borderColor: Theme.border,
                                                fillColor: Color.white.opacity(0.08),
                                                textColor: Theme.ink
                                            )

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(member.name)
                                                    .font(.system(size: 16, weight: .black))
                                                    .foregroundStyle(Theme.ink)
                                                Text("\(member.points) pts")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(Theme.inkSecondary)
                                                Text(lang == .es ? "Elegir rival" : "Choose opponent")
                                                    .textCase(.uppercase)
                                                    .font(.system(size: 11, weight: .black))
                                                    .tracking(0.8)
                                                    .foregroundStyle(Theme.hot)
                                            }

                                            Spacer(minLength: 12)

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Theme.inkTertiary)
                                                .accessibilityHidden(true)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(member.name)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang == .es ? "Cerrar" : "Close") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.ink)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func challengeStepPill(title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
