import SwiftUI
import PhotosUI

// MARK: - BetsyProfileScreen (ScreenProfile)

struct BetsyProfileScreen: View {
    @EnvironmentObject var leagueService: LeagueService
    @AppStorage("displayName") private var displayName: String = ""
    @AppStorage("profileEmail") private var profileEmail: String = ""
    @AppStorage("profileAvatarImageData") private var avatarImageData: Data = Data()
    @AppStorage("betsyProfileAvatarStoreDataV1") private var profileAvatarStoreData: Data = Data()
    @AppStorage("selectedLeagueId") private var selectedLeagueId = ""
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = true
    @AppStorage("hasSeenTour") private var hasSeenTour: Bool = true
    @AppStorage("tutorialSeenForUserIdV1") private var tutorialSeenForUserId = ""
    @AppStorage("hasSeenPlayTutorialV1") private var hasSeenPlayTutorial = false
    @AppStorage("betsyTicketHistoryDataV2") private var ticketHistoryData: Data = Data()
    @AppStorage("notifReminderEnabled") private var notifReminderEnabled: Bool = false
    @AppStorage("notifReminderHour") private var notifReminderHour: Int = 19
    @AppStorage("notifReminderMinute") private var notifReminderMinute: Int = 0
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @AppStorage("isDevModeActive") private var isDevModeActive = false
    @AppStorage("betsyLifetimeStatsV1") private var lifetimeStatsData: Data = Data()
    let tickets: [UserTicket]
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var notifPermissionDenied = false
    @State private var showLeagueSwitcher = false
    @State private var legalKind: BetsyLegalDocumentKind? = nil
    @State private var showEditNameSheet = false
    @State private var editNameDraft = ""
    @State private var showReauthSheet = false
    @State private var reauthPassword = ""
    @State private var reauthError: String? = nil
    #if DEBUG
    @State private var showDevPanel = false
    #endif

    private var todaysTickets: [UserTicket] {
        tickets.filter { Calendar.current.isDateInToday($0.date) && !$0.isWithdrawn }
    }
    private var dailyLimit: Int { activeLeague?.settings.betsPerActiveDay ?? 0 }
    private var betsLeftToday: Int { max(dailyLimit - todaysTickets.count, 0) }
    private var isWithinBetWindow: Bool {
        guard let settings = activeLeague?.settings else { return true }
        let weekday = Calendar.current.component(.weekday, from: Date())
        switch settings.betWindowPreset {
        case .daily: return true
        case .weekdays: return (2...6).contains(weekday)
        case .weekend: return weekday == 1 || weekday == 7
        case .custom: return settings.activeWeekdays.contains(where: { $0.calendarWeekday == weekday })
        }
    }

    private func refreshReminderSchedule() {
        BetReminderScheduler.schedule(
            enabled: notifReminderEnabled,
            hour: notifReminderHour,
            minute: notifReminderMinute,
            leagueName: activeLeague?.name,
            betsLeftToday: betsLeftToday,
            dailyLimit: dailyLimit,
            isWithinBetWindow: isWithinBetWindow
        )
        BetReminderScheduler.scheduleEngagement(
            enabled: notifReminderEnabled,
            leagueName: activeLeague?.name,
            pendingBets: betsLeftToday,
            lang: appLang.rawValue
        )
    }

    private func toggleReminder(_ on: Bool) {
        if on {
            BetReminderScheduler.requestAuthorization { granted in
                if granted {
                    notifReminderEnabled = true
                    notifPermissionDenied = false
                    refreshReminderSchedule()
                } else {
                    notifReminderEnabled = false
                    notifPermissionDenied = true
                }
            }
        } else {
            notifReminderEnabled = false
            BetReminderScheduler.cancelAll()
        }
    }

    private func performSignOut() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        // Clear local user state — back to onboarding
        displayName = ""
        profileEmail = ""
        avatarImageData = Data()
        selectedLeagueId = ""
        ticketHistoryData = Data()
        notifReminderEnabled = false
        BetReminderScheduler.cancel()
        leagueService.setDeveloperProfile(.real)
        leagueService.resetSession()
        tutorialSeenForUserId = ""
        hasSeenPlayTutorial = false
        hasSeenOnboarding = false
    }

    private func performDeleteAccount() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        let deletingUid = leagueService.currentUserId
        let deletingDevAccount = leagueService.currentDevProfile != .real
        leagueService.deleteCurrentAccount { success in
            guard success else { return }
            if let deletingUid {
                var avatars = ProfileAvatarStore.load(from: profileAvatarStoreData)
                avatars.removeValue(forKey: deletingUid)
                profileAvatarStoreData = ProfileAvatarStore.save(avatars)
            }
            selectedLeagueId = ""
            if !deletingDevAccount {
                displayName = ""
                profileEmail = ""
                avatarImageData = Data()
                ticketHistoryData = Data()
                notifReminderEnabled = false
                BetReminderScheduler.cancel()
            }
            tutorialSeenForUserId = ""
            hasSeenPlayTutorial = false
            hasSeenTour = false
            hasSeenOnboarding = false
        }
    }

    // MARK: - Computed helpers

    private var activeLeague: FriendLeague? {
        ActiveLeagueStore.resolve(from: leagueService.myLeagues, selectedId: selectedLeagueId)
    }

    private var myMember: LeagueMember? {
        guard let league = activeLeague,
              let uid = leagueService.currentUserId else { return nil }
        return leagueService.membersByLeague[league.id]?.first(where: { $0.id == uid })
    }

    private var myBalance: Int { myMember?.points ?? 0 }
    private var myBalanceNet: Int { myMember?.pointsToday ?? 0 }

    private var myRank: Int? {
        guard let league = activeLeague, let uid = leagueService.currentUserId else { return nil }
        let sorted = (leagueService.membersByLeague[league.id] ?? [])
            .sorted { $0.points > $1.points }
        return sorted.firstIndex(where: { $0.id == uid }).map { $0 + 1 }
    }

    private var userName: String {
        if leagueService.currentDevProfile != .real {
            return leagueService.currentDevProfile.displayName
        }
        let name = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        return name.isEmpty ? (appLang == .es ? "Jugador" : "Player") : name
    }

    private var userHandle: String {
        "@" + userName.lowercased().replacingOccurrences(of: " ", with: ".")
    }

    // MARK: - Lifetime stats (persist through dev day simulation / ticket pruning)

    private var lifetimeScopeKey: String {
        let uid = leagueService.currentUserId ?? "anonymous"
        let lid = selectedLeagueId
        return "\(uid)|\(lid)"
    }

    private var lifetimeStats: LifetimeStats {
        LifetimeStatsStore.read(scope: lifetimeScopeKey, from: lifetimeStatsData)
    }

    private func refreshLifetimeStats() {
        let uid = leagueService.currentUserId ?? "anonymous"
        let lid = selectedLeagueId
        guard !lid.isEmpty else { return }
        let key = "\(uid)|\(lid)"
        let allTickets = TicketStore.loadHistory(from: ticketHistoryData)[key] ?? []
        LifetimeStatsStore.absorb(tickets: allTickets, for: key, in: &lifetimeStatsData)
    }

    // Legacy fallbacks (used only for arena record which isn't in LifetimeStats)
    private var resolvedTickets: [UserTicket] {
        tickets.filter { $0.isResultKnown && !$0.isWithdrawn }
    }
    private var wonTickets: [UserTicket] { resolvedTickets.filter(\.wasWon) }

    private var currentAvatarData: Data? {
        if let uid = leagueService.currentUserId {
            let avatars = ProfileAvatarStore.load(from: profileAvatarStoreData)
            if let data = avatars[uid], !data.isEmpty {
                return data
            }
        }
        guard leagueService.currentDevProfile == .real else { return nil }
        return avatarImageData.isEmpty ? nil : avatarImageData
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appLang == .es ? "tu perfil" : "your profile")
                        .font(.jbMono(11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(DS.fg3)
                    Text(appLang == .es ? "Perfil" : "Profile")
                        .font(.bebas(32))
                        .tracking(-0.5)
                        .foregroundStyle(DS.fg)
                }
                Spacer()
                Button {
                    guard !leagueService.myLeagues.isEmpty else { return }
                    UISelectionFeedbackGenerator().selectionChanged()
                    showLeagueSwitcher = true
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.fg)
                        .frame(width: 40, height: 40)
                        .background(DS.bg2)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(DS.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appLang == .es ? "Cambiar liga seleccionada" : "Change selected league")
            }
            .padding(.horizontal, DS.screenHPad)
            .padding(.bottom, 12)
            .sheet(isPresented: $showLeagueSwitcher) {
                LeagueSwitcherSheet(isPresented: $showLeagueSwitcher)
                    .environmentObject(leagueService)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }

            ScrollView {
                VStack(spacing: 0) {
                    // Identity card
                    ZStack(alignment: .topLeading) {
                        DSArenaGrid(opacity: 0.3)
                        HStack(spacing: 16) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                BetsyAvatarView(
                                    imageData: currentAvatarData,
                                    name: userName,
                                    size: 72,
                                    borderColor: DS.accentLine,
                                    fillColor: DS.accent,
                                    textColor: DS.accentInk
                                )
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundStyle(DS.accentInk)
                                        .frame(width: 22, height: 22)
                                        .background(DS.accent)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(DS.bg, lineWidth: 2))
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(appLang == .es ? "Cambiar foto de perfil" : "Change profile photo")
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(userHandle)
                                        .font(.bebas(22))
                                        .tracking(-0.4)
                                        .foregroundStyle(DS.fg)
                                    if let rank = myRank {
                                        DSPill(text: "RANK \(rank)", bg: DS.accentSoft,
                                               border: DS.accentLine, fg: DS.accent, fontSize: 9)
                                    }
                                    if leagueService.currentDevProfile == .real {
                                        Button {
                                            editNameDraft = displayName
                                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                                .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
                                            showEditNameSheet = true
                                        } label: {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(DS.fg3)
                                                .frame(width: 26, height: 26)
                                                .background(DS.bg2)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(DS.line, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                        .accessibilityLabel(appLang == .es ? "Editar nombre" : "Edit name")
                                    }
                                }
                                Text(leagueService.currentDevProfile == .real
                                     ? profileEmail
                                     : (leagueService.currentDevProfile.testerEmail ?? (appLang == .es ? "Perfil tester local" : "Local tester profile")))
                                    .font(.system(size: 12))
                                    .foregroundStyle(DS.fg3)
                                Text(activeLeague.map { appLang == .es ? "Liga: \($0.name)" : "League: \($0.name)" }
                                     ?? (appLang == .es ? "Sin liga seleccionada" : "No selected league"))
                                    .font(.system(size: 12))
                                    .foregroundStyle(DS.fg3)
                                HStack(spacing: 6) {
                                    DSPill(text: appLang == .es
                                           ? "\(leagueService.myLeagues.count) liga\(leagueService.myLeagues.count == 1 ? "" : "s")"
                                           : "\(leagueService.myLeagues.count) league\(leagueService.myLeagues.count == 1 ? "" : "s")",
                                           fontSize: 10)
                                }
                                .padding(.top, 6)
                            }
                        }
                        .padding(20)
                    }
                    .background(DS.bg1)
                    .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                            .stroke(DS.line, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    // Balance card
                    if let league = activeLeague {
                        balanceCard(league: league)
                    } else {
                        noLeagueCard
                    }

                    // Stats grid
                    DSSectionRow(title: appLang == .es ? "Estadísticas · temporada" : "Stats · season")

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                              spacing: 10) {
                        let ls = lifetimeStats
                        StatBox(label: appLang == .es ? "Acierto" : "Accuracy",
                                value: ls.resolvedCount == 0 ? "0%" : "\(ls.hitRate)%",
                                sub: appLang == .es ? "\(ls.wonCount) de \(ls.resolvedCount)" : "\(ls.wonCount) of \(ls.resolvedCount)",
                                bar: CGFloat(ls.hitRate))
                        StatBox(label: appLang == .es ? "Cuota media" : "Avg. odds",
                                value: ls.averageOdd.map { String(format: "%.2f", $0) } ?? "—",
                                sub: ls.totalBetCount == 0 ? (appLang == .es ? "sin apuestas" : "no bets") : (appLang == .es ? "por pick" : "per pick"))
                        StatBox(label: appLang == .es ? "Apuestas jugadas" : "Bets placed",
                                value: "\(ls.totalBetCount)",
                                sub: appLang == .es ? "acumulado temporada" : "season total")
                        StatBox(label: appLang == .es ? "Retos arena" : "Arena duels",
                                value: arenaRecordText,
                                sub: appLang == .es ? "duelos activos" : "active duels",
                                arena: true)
                        StatBox(label: appLang == .es ? "Mejor racha" : "Best streak",
                                value: ls.bestStreak == 0 ? "—" : "W\(ls.bestStreak)",
                                sub: appLang == .es ? "apuestas ganadas" : "bets won")
                        StatBox(label: appLang == .es ? "Stake medio" : "Avg. stake",
                                value: ls.averageStake.map { "\($0)" } ?? "—",
                                sub: "pts")
                    }
                    .padding(.horizontal, 20)

                    // Settings
                    DSSectionRow(title: appLang == .es ? "Ajustes" : "Settings")

                    VStack(spacing: 0) {
                        LanguageRow()
                    }
                    .dsCard()
                    .padding(.horizontal, 20)

                    DSSectionRow(title: appLang == .es ? "Legal y privacidad" : "Legal and privacy")

                    VStack(spacing: 0) {
                        LegalRow(
                            icon: "hand.raised.fill",
                            title: appLang == .es ? "Política de privacidad" : "Privacy policy",
                            subtitle: appLang == .es ? "Datos, fotos, ligas, notificaciones y proveedores" : "Data, photos, leagues, notifications and providers"
                        ) {
                            legalKind = .privacy
                        }
                        Divider().background(DS.line)
                        LegalRow(
                            icon: "doc.text.fill",
                            title: appLang == .es ? "Términos de uso" : "Terms of use",
                            subtitle: appLang == .es ? "Puntos virtuales, juego limpio y reglas de la app" : "Virtual points, fair play and app rules"
                        ) {
                            legalKind = .terms
                        }
                    }
                    .dsCard()
                    .padding(.horizontal, 20)

                    // Notifications section
                    DSSectionRow(title: appLang == .es ? "Notificaciones" : "Notifications")

                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: notifReminderEnabled ? "bell.fill" : "bell.slash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(notifReminderEnabled ? DS.accent : DS.fg3)
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appLang == .es ? "Activar notificaciones" : "Enable notifications")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(DS.fg)
                                Text(appLang == .es
                                     ? "Apuestas, retos, resultados y motivación"
                                     : "Bets, challenges, results and motivation")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DS.fg3)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { notifReminderEnabled },
                                set: { toggleReminder($0) }
                            ))
                            .labelsHidden()
                            .tint(DS.accent)
                        }

                        if notifPermissionDenied {
                            Divider().background(DS.line)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(DS.warn)
                                    Text(appLang == .es ? "Permiso denegado. Actívalo en Ajustes › Notificaciones › Betsy." : "Permission denied. Enable it in Settings › Notifications › Betsy.")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(DS.fg2)
                                    Spacer(minLength: 0)
                                }
                                Button {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Text(appLang == .es ? "Abrir Ajustes" : "Open Settings")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(DS.accentInk)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(DS.accent)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(14)
                    .dsCard()
                    .padding(.horizontal, 20)

                    // Instructions button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        hasSeenTour = false
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .accessibilityHidden(true)
                            Text(appLang == .es ? "Ver instrucciones" : "Instructions")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DS.fg3)
                        }
                        .foregroundStyle(DS.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(DS.accent.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                                .stroke(DS.accent.opacity(0.22), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Button(action: { showSignOutConfirm = true }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                                .accessibilityHidden(true)
                            Text(appLang == .es ? "Cerrar sesión" : "Sign out")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                        }
                        .foregroundStyle(DS.loss)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(DS.loss.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                                .stroke(DS.loss.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Button(action: { showDeleteAccountConfirm = true }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appLang == .es ? "Eliminar cuenta" : "Delete account")
                                    .font(.system(size: 14, weight: .bold))
                                Text(deleteAccountSubtitle)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(DS.fg3)
                            }
                            Spacer()
                        }
                        .foregroundStyle(DS.loss)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(DS.loss.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                                .stroke(DS.loss.opacity(0.22), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .disabled(leagueService.isLoading)

                    // DEV button — solo visible cuando el modo Dev ya esta activo.
                    #if DEBUG
                    if isDevModeActive {
                        Button {
                            showDevPanel = true
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(leagueService.currentDevProfile == .real ? DS.win : DS.warn)
                                    .frame(width: 6, height: 6)
                                Text("DEV · \(leagueService.currentDevProfile.title.uppercased())")
                                    .font(.jbMono(10, weight: .semibold))
                                    .tracking(2)
                                    .foregroundStyle(DS.fg3)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(DS.bg2)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(DS.line2, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                        .padding(.bottom, 30)
                    } else {
                        Color.clear.frame(height: 30)
                    }
                    #else
                    Color.clear.frame(height: 30)
                    #endif
                }
            }
        }
        .background(DS.bg.ignoresSafeArea())
        .onAppear {
            if let league = activeLeague {
                leagueService.loadMembers(for: league)
            }
            refreshLifetimeStats()
            // Re-validate authorization (could have changed in Settings)
            if notifReminderEnabled {
                BetReminderScheduler.currentAuthorizationStatus { status in
                    if status == .denied {
                        notifReminderEnabled = false
                        notifPermissionDenied = true
                        BetReminderScheduler.cancel()
                    } else {
                        refreshReminderSchedule()
                    }
                }
            }
        }
        .onChange(of: tickets.count) { _, _ in
            refreshLifetimeStats()
            if notifReminderEnabled { refreshReminderSchedule() }
        }
        .onChange(of: selectedLeagueId) { _, _ in
            refreshLifetimeStats()
            if notifReminderEnabled { refreshReminderSchedule() }
        }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let compressed = UIImage(data: data)?.jpegData(compressionQuality: 0.72) else { return }
                await MainActor.run {
                    if let uid = leagueService.currentUserId {
                        var avatars = ProfileAvatarStore.load(from: profileAvatarStoreData)
                        avatars[uid] = compressed
                        profileAvatarStoreData = ProfileAvatarStore.save(avatars)
                    }
                    if leagueService.currentDevProfile == .real {
                        avatarImageData = compressed
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .betsyTabReset)) { notif in
            guard let tab = notif.object as? BetsyTab, tab == .profile else { return }
            #if DEBUG
            showDevPanel = false
            #endif
        }
        .alert(appLang == .es ? "¿Cerrar sesión?" : "Sign out?", isPresented: $showSignOutConfirm) {
            Button(appLang == .es ? "Cerrar sesión" : "Sign out", role: .destructive) { performSignOut() }
            Button(appLang == .es ? "Cancelar" : "Cancel", role: .cancel) {}
        } message: {
            Text(appLang == .es ? "Volverás al inicio. Tu liga y tu balance siguen guardados en el servidor." : "You'll return to the start. Your league and balance remain saved on the server.")
        }
        .alert(deleteAccountTitle, isPresented: $showDeleteAccountConfirm) {
            Button(deleteAccountButtonTitle, role: .destructive) { performDeleteAccount() }
            Button(appLang == .es ? "Cancelar" : "Cancel", role: .cancel) {}
        } message: {
            Text(deleteAccountMessage)
        }
        #if DEBUG
        .sheet(isPresented: $showDevPanel) {
            DeveloperPanelView()
                .environmentObject(leagueService)
        }
        #endif
        .sheet(item: $legalKind) { kind in
            BetsyLegalDocumentView(kind: kind)
        }
        // Edit display name sheet
        .sheet(isPresented: $showEditNameSheet) {
            EditDisplayNameSheet(
                draft: $editNameDraft,
                appLang: appLang,
                onSave: { newName in
                    let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
                    guard !clean.isEmpty else { return }
                    displayName = clean
                    showEditNameSheet = false
                },
                onCancel: { showEditNameSheet = false }
            )
            .presentationDetents([.height(240)])
            .presentationDragIndicator(.visible)
        }
        // Re-auth sheet (shown when account deletion requires recent login)
        .sheet(isPresented: $showReauthSheet) {
            ReauthSheet(
                email: profileEmail,
                password: $reauthPassword,
                errorMessage: reauthError,
                appLang: appLang,
                onConfirm: {
                    reauthError = nil
                    leagueService.signInAccount(email: profileEmail, password: reauthPassword) { result in
                        switch result {
                        case .success:
                            showReauthSheet = false
                            reauthPassword = ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                performDeleteAccount()
                            }
                        case .failure(let err):
                            reauthError = leagueService.authMessage(for: err)
                        }
                    }
                },
                onCancel: {
                    showReauthSheet = false
                    reauthPassword = ""
                    reauthError = nil
                }
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: leagueService.errorMessage) { _, newMsg in
            guard let msg = newMsg else { return }
            let isReauth = msg.contains("vuelve a iniciar sesión") || msg.contains("sign in again")
            if isReauth && leagueService.currentDevProfile == .real {
                leagueService.errorMessage = nil
                showReauthSheet = true
            }
        }
    }

    private var deleteAccountSubtitle: String {
        if leagueService.currentDevProfile == .real {
            return appLang == .es
                ? "Borra tu perfil, ligas creadas, membresías y retos"
                : "Deletes your profile, owned leagues, memberships and challenges"
        }
        return appLang == .es
            ? "Borra este tester, sus ligas, membresías y retos"
            : "Deletes this tester, leagues, memberships and challenges"
    }

    private var deleteAccountTitle: String {
        if leagueService.currentDevProfile == .real {
            return appLang == .es ? "¿Eliminar cuenta definitivamente?" : "Delete account permanently?"
        }
        return appLang == .es ? "¿Eliminar este tester?" : "Delete this tester?"
    }

    private var deleteAccountButtonTitle: String {
        if leagueService.currentDevProfile == .real {
            return appLang == .es ? "Eliminar mi cuenta" : "Delete my account"
        }
        return appLang == .es ? "Eliminar \(leagueService.currentDevProfile.title)" : "Delete \(leagueService.currentDevProfile.title)"
    }

    private var deleteAccountMessage: String {
        if leagueService.currentDevProfile == .real {
            return appLang == .es
                ? "Esto borra tu cuenta de acceso, perfil, ligas creadas, membresías y retos. No se puede deshacer."
                : "This deletes your login account, profile, owned leagues, memberships and challenges. It cannot be undone."
        }
        return appLang == .es
            ? "Esto borra el tester activo, sus ligas creadas, membresías y retos. Volverás a la pantalla inicial."
            : "This deletes the active tester, owned leagues, memberships and challenges. You will return to the start screen."
    }

    private var arenaRecordText: String {
        let leagueId = activeLeague?.id ?? ""
        let duels = leagueService.arenasByLeague[leagueId] ?? []
        let active = duels.filter { $0.status == "active" || $0.status == "resolved" }
        guard !active.isEmpty else { return "0/0" }
        let wins = active.filter { $0.winnerId == leagueService.currentUserId || $0.winnerId == "both" }.count
        return "\(wins)/\(active.count)"
    }

    // MARK: - Balance card (when league exists)

    @ViewBuilder
    private func balanceCard(league: FriendLeague) -> some View {
        let net = myBalanceNet
        let netSign = net >= 0 ? "+" : ""
        let bal = myBalance

        VStack(alignment: .leading, spacing: 0) {
            DSEyebrow(text: appLang == .es ? "\(league.name) · balance actual" : "\(league.name) · current balance")
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("\(netSign)\(net)")
                    .font(.jbMono(72, weight: .black))
                    .tracking(-1)
                    .foregroundStyle(net >= 0 ? DS.fg : DS.loss)
                Text(appLang == .es ? "hoy" : "today")
                    .font(.system(size: 20))
                    .foregroundStyle(DS.fg3)
                    .padding(.leading, 8)
            }
            .padding(.top, 10)

            HStack {
                ProfileMiniStat(label: appLang == .es ? "balance" : "balance", value: "\(bal)", align: .leading)
                Spacer()
                ProfileMiniStat(label: appLang == .es ? "posición" : "rank", value: myRank.map { "\($0)º" } ?? "—", align: .center)
                Spacer()
                ProfileMiniStat(label: appLang == .es ? "liga" : "league", value: league.code, align: .trailing)
            }
            .padding(.top, 14)
        }
        .padding(20)
        .background(DS.bg2)
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                .stroke(DS.line, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - No-league card

    private var noLeagueCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(DS.fg3)
            Text(appLang == .es ? "Sin liga seleccionada" : "No league selected")
                .font(.bebas(22))
                .foregroundStyle(DS.fg)
            Text(appLang == .es ? "Crea o únete a una liga para\nver tu balance y posición." : "Create or join a league to\nsee your balance and ranking.")
                .font(.system(size: 13))
                .foregroundStyle(DS.fg3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(DS.bg1)
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                .stroke(DS.line, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

// MARK: - Profile mini stat

private struct ProfileMiniStat: View {
    let label: String
    let value: String
    var align: HorizontalAlignment = .leading
    var color: Color = DS.fg

    var body: some View {
        VStack(alignment: align, spacing: 2) {
            Text(label)
                .textCase(.uppercase)
                .font(.jbMono(11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(DS.fg3)
            Text(value)
                .font(.jbMono(22, weight: .black))
                .tracking(-0.3)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Stat box (for the 2-column grid)

private struct StatBox: View {
    let label: String
    let value: String
    let sub: String
    var bar: CGFloat? = nil
    var arena: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .textCase(.uppercase)
                .font(.jbMono(11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(arena ? DS.arena : DS.fg3)

            Text(value)
                .font(.jbMono(28, weight: .black))
                .tracking(-0.3)
                .foregroundStyle(arena ? DS.arena : DS.fg)
                .padding(.top, 6)

            Text(sub)
                .font(.system(size: 11))
                .foregroundStyle(DS.fg3)
                .padding(.top, 4)

            if let bar {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DS.bg3)
                        Capsule()
                            .fill(DS.accent)
                            .frame(width: geo.size.width * bar / 100)
                    }
                }
                .frame(height: 3)
                .padding(.top, 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.bg1)
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                .stroke(arena ? DS.arena.opacity(0.3) : DS.line, lineWidth: 1)
        )
    }
}

// MARK: - Settings rows

private struct SettingsRowData: Identifiable {
    let id = UUID()
    let label: String
    var value: String = ""
    var highlight: Bool = false
    var isDestructive: Bool = false
}


private struct LanguageRow: View {
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    var body: some View {
        HStack {
            Text(appLang == .es ? "Idioma" : "Language")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.fg2)
            Spacer()
            HStack(spacing: 2) {
                ForEach([AppLang.es, AppLang.en], id: \.self) { option in
                    Button(option == .es ? "ES" : "EN") {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                            appLang = option
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(appLang == option ? DS.accentInk : DS.fg3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(appLang == option ? DS.accent : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
            }
            .padding(2)
            .background(DS.bg3)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(DS.line, lineWidth: 1)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(appLang == .es ? "Idioma, actualmente \(appLang == .es ? "Español" : "English")" : "Language, currently \(appLang == .es ? "Español" : "English")")
        .accessibilityHint(appLang == .es ? "Doble toque para cambiar idioma" : "Double tap to change language")
    }
}

private struct SettingsRow: View {
    let row: SettingsRowData

    var body: some View {
        HStack {
            Text(row.label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.fg2)
            Spacer()
            if !row.value.isEmpty {
                Text(row.value)
                    .font(.system(size: 12))
                    .foregroundStyle(row.highlight ? DS.accent : DS.fg3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

private struct LegalRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.accent)
                    .frame(width: 28, height: 28)
                    .background(DS.accentSoft)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(DS.accentLine, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.fg)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.fg3)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.fg3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Edit display name sheet

private struct EditDisplayNameSheet: View {
    @Binding var draft: String
    let appLang: AppLang
    let onSave: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(appLang == .es ? "Editar nombre" : "Edit name")
                .font(.bebas(24))
                .foregroundStyle(DS.fg)
                .padding(.top, 8)

            TextField(appLang == .es ? "Tu nombre" : "Your name", text: $draft)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.fg)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(DS.bg2)
                .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                        .stroke(DS.line, lineWidth: 1)
                )
                .submitLabel(.done)
                .onSubmit { onSave(draft) }

            HStack(spacing: 12) {
                Button(appLang == .es ? "Cancelar" : "Cancel", action: onCancel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.fg2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DS.bg2)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(DS.line, lineWidth: 1))
                    .buttonStyle(.plain)

                Button(appLang == .es ? "Guardar" : "Save") { onSave(draft) }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DS.accentInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? DS.fg3 : DS.accent)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .background(DS.bg)
    }
}

// MARK: - Re-authentication sheet (shown before account deletion when session expired)

private struct ReauthSheet: View {
    let email: String
    @Binding var password: String
    let errorMessage: String?
    let appLang: AppLang
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(appLang == .es ? "Confirma tu identidad" : "Confirm your identity")
                    .font(.bebas(24))
                    .foregroundStyle(DS.fg)
                Text(appLang == .es
                     ? "Por seguridad, introduce tu contraseña para eliminar la cuenta."
                     : "For security, enter your password to delete your account.")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.fg3)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                HStack {
                    Text(email)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.fg2)
                    Spacer()
                }
                SecureField(appLang == .es ? "Contraseña" : "Password", text: $password)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.fg)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(DS.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                            .stroke(DS.line, lineWidth: 1)
                    )
                    .submitLabel(.done)
                    .onSubmit { if !password.isEmpty { onConfirm() } }

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.loss)
                        .multilineTextAlignment(.center)
                }
            }

            HStack(spacing: 12) {
                Button(appLang == .es ? "Cancelar" : "Cancel", action: onCancel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.fg2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DS.bg2)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(DS.line, lineWidth: 1))
                    .buttonStyle(.plain)

                Button(appLang == .es ? "Eliminar cuenta" : "Delete account", action: onConfirm)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DS.loss)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DS.loss.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(DS.loss.opacity(0.35), lineWidth: 1))
                    .buttonStyle(.plain)
                    .disabled(password.isEmpty)
            }
        }
        .padding(24)
        .background(DS.bg)
    }
}
