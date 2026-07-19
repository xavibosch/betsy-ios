import SwiftUI
import Combine

// MARK: - Developer Panel (DEBUG only)
// Accessible from the "DEV" button at the bottom of the Profile screen.
// Lets the developer switch between 4 pre-seeded tester identities.

#if DEBUG

// MARK: - ViewModel

@MainActor
final class DeveloperPanelViewModel: ObservableObject {
    @Published var toast: String? = nil

    func showToast(_ msg: String) {
        toast = msg
    }
}

// MARK: - Panel View

struct DeveloperPanelView: View {
    @EnvironmentObject var leagueService: LeagueService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var vm = DeveloperPanelViewModel()
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("betsyTicketHistoryDataV2") private var ticketHistoryData: Data = Data()
    @AppStorage("displayName") private var displayName = ""
    @AppStorage("profileEmail") private var profileEmail = ""
    @AppStorage("profileAvatarImageData") private var avatarImageData: Data = Data()
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @State private var showDeleteDevDataAlert = false
    @State private var profileToDelete: DevProfile? = nil

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DEV · SWITCH PROFILE")
                            .font(.jbMono(9, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(DS.accent)
                        Text(appLang == .es ? "Developer" : "Developer")
                            .font(.bebas(28))
                            .foregroundStyle(DS.fg)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.fg)
                            .dsBackButton()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 12) {
                        // Profile cards
                        DSSectionRow(title: appLang == .es ? "Cambiar cuenta" : "Switch account")
                            .padding(.top, 4)

                        ForEach(DevProfile.allCases) { profile in
                            ProfileSwitcherCard(
                                profile: profile,
                                isActive: leagueService.currentDevProfile == profile,
                                isCreated: leagueService.isDeveloperTesterCreated(profile),
                                leagueCount: leagueService.currentDevProfile == profile ? leagueService.myLeagues.count : nil
                            ) {
                                if profile == .real || leagueService.isDeveloperTesterCreated(profile) {
                                    leagueService.setDeveloperProfile(profile)
                                    vm.showToast("→ \(profile.title)")
                                } else {
                                    leagueService.seedDeveloperTester(profile) { success in
                                        if success { vm.showToast("+ \(profile.title)") }
                                    }
                                }
                            } onDelete: {
                                profileToDelete = profile
                            }
                        }

                        // Active league info
                        if !leagueService.myLeagues.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(appLang == .es ? "LIGAS DEL PERFIL ACTIVO" : "ACTIVE PROFILE LEAGUES")
                                    .font(.jbMono(10, weight: .semibold))
                                    .tracking(1.8)
                                    .foregroundStyle(DS.fg3)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 10)

                                ForEach(leagueService.myLeagues) { league in
                                    HStack(spacing: 10) {
                                        Image(systemName: "trophy.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(DS.accent)
                                            .frame(width: 20)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(league.name)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(DS.fg)
                                            Text(appLang == .es ? "Código: \(league.code) · \(league.members) miembros" : "Code: \(league.code) · \(league.members) members")
                                                .font(.jbMono(9))
                                                .foregroundStyle(DS.fg3)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    if league.id != leagueService.myLeagues.last?.id {
                                        Divider().background(DS.line)
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                            .background(DS.bg1)
                            .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                                .stroke(DS.line, lineWidth: 1))
                        }

                        // Danger zone
                        DSSectionRow(title: appLang == .es ? "Zona peligrosa" : "Danger zone")
                            .padding(.top, 4)

                        VStack(spacing: 8) {
                            DangerActionButton(
                                icon: "trash.fill",
                                title: appLang == .es ? "Borrar datos dev" : "Delete dev data",
                                subtitle: appLang == .es ? "Elimina ligas y datos de los 4 testers" : "Deletes leagues and data for the 4 testers"
                            ) {
                                showDeleteDevDataAlert = true
                            }

                            DangerActionButton(
                                icon: "person.crop.circle.badge.xmark",
                                title: appLang == .es ? "Reiniciar experiencia inicial" : "Reset initial experience",
                                subtitle: appLang == .es ? "Simula onboarding sin borrar datos ni cuenta" : "Simulates onboarding without clearing data or account"
                            ) {
                                // Simulated only — no Firebase, no data wipe, profile stays intact
                                UserDefaults.standard.set(true, forKey: "devSimulatingOnboarding")
                                hasSeenOnboarding = false
                                vm.showToast(appLang == .es ? "Onboarding reiniciado (simulado)" : "Onboarding reset (simulated)")
                            }

                            DangerActionButton(
                                icon: "clock.arrow.2.circlepath",
                                title: appLang == .es ? "Reset límite Arena" : "Reset Arena limit",
                                subtitle: appLang == .es ? "Permite volver a retar hoy" : "Allows another challenge today"
                            ) {
                                leagueService.clearArenaDailyLimits()
                                vm.showToast(appLang == .es ? "Límite Arena reiniciado" : "Arena limit reset")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }

            // Toast
            if let toast = vm.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.jbMono(13, weight: .semibold))
                        .foregroundStyle(DS.accentInk)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(DS.accent)
                        .clipShape(Capsule())
                        .padding(.bottom, 30)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(reduceMotion ? nil : .default) { vm.toast = nil }
                            }
                        }
                }
                .animation(reduceMotion ? nil : .spring(response: 0.35), value: vm.toast)
            }
        }
        // Delete dev data confirmation
        .alert(appLang == .es ? "¿Borrar todos los datos dev?" : "Delete all dev data?",
               isPresented: $showDeleteDevDataAlert) {
            Button(appLang == .es ? "Borrar" : "Delete", role: .destructive) {
                leagueService.resetDeveloperData()
                vm.showToast(appLang == .es ? "Datos dev eliminados" : "Dev data deleted")
            }
            Button(appLang == .es ? "Cancelar" : "Cancel", role: .cancel) {}
        } message: {
            Text(appLang == .es
                 ? "Se eliminarán las ligas y datos de los 4 testers. No se puede deshacer."
                 : "Leagues and data for all 4 testers will be deleted. This cannot be undone.")
        }
        // Delete tester profile confirmation
        .alert(
            appLang == .es
                ? "¿Borrar \(profileToDelete?.title ?? "tester")?"
                : "Delete \(profileToDelete?.title ?? "tester")?",
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            )
        ) {
            Button(appLang == .es ? "Borrar" : "Delete", role: .destructive) {
                if let profile = profileToDelete {
                    leagueService.deleteDeveloperTester(profile) { success in
                        if success {
                            vm.showToast(appLang == .es ? "\(profile.title) borrado" : "\(profile.title) deleted")
                        }
                    }
                    profileToDelete = nil
                }
            }
            Button(appLang == .es ? "Cancelar" : "Cancel", role: .cancel) { profileToDelete = nil }
        } message: {
            Text(appLang == .es ? "Se eliminarán sus datos de tester." : "This tester's data will be deleted.")
        }
    }
}

// MARK: - Profile Card

private struct ProfileSwitcherCard: View {
    let profile: DevProfile
    let isActive: Bool
    let isCreated: Bool
    let leagueCount: Int?
    let onSwitch: () -> Void
    let onDelete: () -> Void
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    var body: some View {
        let vibe = profile.vibe
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(vibe.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Text(vibe.emoji)
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(profile.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DS.fg)
                        if isActive {
                            DSPill(text: appLang == .es ? "ACTIVO" : "ACTIVE", bg: DS.accentSoft, border: DS.accentLine,
                                   fg: DS.accent, fontSize: 9)
                        }
                    }
                    if profile == .real {
                        Text(appLang == .es ? "Tu cuenta real · Firebase Auth" : "Your real account · Firebase Auth")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.fg3)
                    } else if let uid = profile.devUserId {
                        Text(uid)
                            .font(.jbMono(9))
                            .foregroundStyle(DS.fg3)
                    }
                    if isActive {
                        Text(appLang == .es
                             ? "\((leagueCount ?? 0)) liga\((leagueCount ?? 0) == 1 ? "" : "s") cargada\((leagueCount ?? 0) == 1 ? "" : "s")"
                             : "\((leagueCount ?? 0)) league\((leagueCount ?? 0) == 1 ? "" : "s") loaded")
                            .font(.system(size: 11))
                            .foregroundStyle((leagueCount ?? 0) > 0 ? DS.win : DS.fg3)
                    } else if profile != .real && !isCreated {
                        Text(appLang == .es ? "Sin crear · toca + para probar" : "Not created · tap + to test")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.fg3)
                    }
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DS.accent)
                } else if profile != .real && isCreated {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DS.loss)
                            .frame(width: 36, height: 36)
                            .background(DS.loss.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if !isActive {
                Button(action: onSwitch) {
                    HStack(spacing: 8) {
                        Image(systemName: profile == .real ? "person.crop.circle" : (isCreated ? "person.fill.checkmark" : "plus"))
                            .font(.system(size: 12, weight: .black))
                        Text(profile == .real
                             ? (appLang == .es ? "Usar mi cuenta" : "Use my account")
                             : (isCreated
                                ? (appLang == .es ? "Entrar como tester" : "Enter as tester")
                                : (appLang == .es ? "Añadir tester" : "Add tester")))
                            .font(.system(size: 13, weight: .black))
                    }
                    .foregroundStyle(profile == .real ? DS.fg : DS.accentInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(profile == .real ? DS.bg3 : DS.accent)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(profile == .real ? DS.line2 : DS.accentLine, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(isActive ? DS.accent.opacity(0.06) : DS.bg1)
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                .stroke(isActive ? DS.accentLine : DS.line, lineWidth: isActive ? 1.5 : 1)
        )
    }
}

// MARK: - Danger button

private struct DangerActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.loss)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.loss)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.fg3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.fg3)
            }
            .padding(16)
            .background(DS.bg1)
            .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                .stroke(DS.loss.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#endif
