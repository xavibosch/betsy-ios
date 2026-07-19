import SwiftUI
import Combine

// MARK: - Root App View
struct HomeView: View {
    @EnvironmentObject var leagueService: LeagueService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasSeenTour") private var hasSeenTour = false
    @AppStorage("selectedLanguage") private var selectedLanguage: AppLang = .es
    @AppStorage("betsyFunctionalDemoResetV1") private var didRunFunctionalDemoReset = false
    @AppStorage("betsyFreshStartV3") private var didRunFreshStartV3 = false
    @AppStorage("displayName") private var displayName = ""
    @AppStorage("profileEmail") private var profileEmail = ""
    @AppStorage("devProfile") private var devProfileRaw = DevProfile.real.rawValue
    @AppStorage("betsyTicketHistoryDataV2") private var ticketHistoryData: Data = Data()
    @AppStorage("profileAvatarImageData") private var avatarImageData: Data = Data()
    @AppStorage("isDevModeActive") private var isDevModeActive = false
    @State private var showSplash = true
    @State private var selectedTab: BetsyTab = .home

    var body: some View {
        ZStack {
            if showSplash {
                SplashView(showSplash: $showSplash)
                    .transition(.opacity)
            } else if !hasSeenOnboarding {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            } else if !hasSeenTour {
                OnboardingTourView(hasSeenTour: $hasSeenTour)
                    .transition(.opacity)
            } else {
                BetsyTabContainer(selectedTab: $selectedTab)
            }
        }
        .environment(\.locale, Locale(identifier: selectedLanguage.localeIdentifier))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: showSplash)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: hasSeenOnboarding)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: hasSeenTour)
        .onAppear(perform: runMigrationsIfNeeded)
    }

    private func runMigrationsIfNeeded() {
        // Migration V1 stub — neutralised.
        didRunFunctionalDemoReset = true

        // Migration V3 — one-time fresh production start.
        // Skipped when dev mode is already active so we never wipe dev state.
        guard !didRunFreshStartV3 else { return }
        didRunFreshStartV3 = true

        // Dev mode already bootstrapped — nothing to reset
        guard !isDevModeActive else { return }

        // Clear production identity and content
        hasSeenOnboarding  = false
        hasSeenTour        = false
        displayName        = ""
        profileEmail       = ""
        ticketHistoryData  = Data()
        avatarImageData    = Data()

        // Ensure dev-mode flag is off
        devProfileRaw      = DevProfile.real.rawValue
        SportsDataDevelopmentConfig.applyDevMode(false)

        // Sign out Firebase → triggers anonymous re-auth in LeagueService.init
        leagueService.resetSession()
    }
}

// MARK: - Tab Container
struct BetsyTabContainer: View {
    @Binding var selectedTab: BetsyTab
    @EnvironmentObject var leagueService: LeagueService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @AppStorage("betsyTicketHistoryDataV2") private var ticketHistoryData: Data = Data()
    @AppStorage("selectedLeagueId") private var selectedLeagueId = ""
    @AppStorage("notifReminderEnabled") private var notifReminderEnabled: Bool = false
    @AppStorage("notifReminderHour") private var notifReminderHour: Int = 19
    @AppStorage("notifReminderMinute") private var notifReminderMinute: Int = 0

    // Dev-mode state (persists so returning to dev mode keeps what was set up)
    @AppStorage("isDevModeActive") private var isDevModeActive = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasSeenTour") private var hasSeenTour = false
    @AppStorage("displayName") private var displayName = ""
    @AppStorage("profileEmail") private var profileEmail = ""
    @AppStorage("profileAvatarImageData") private var avatarImageData: Data = Data()
    @AppStorage("betsyProfileAvatarStoreDataV1") private var profileAvatarStoreData: Data = Data()
    @AppStorage("devProfile") private var devProfileRaw = DevProfile.real.rawValue

    // Bet placed overlay state
    @State private var showBetPlaced = false
    @State private var lastPlacedTicket: UserTicket? = nil
    @State private var lastNotifiedArenaInviteId: String? = nil
    private let arenaResolutionTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

    // Dev-mode dialog
    @State private var showDevModeDialog = false

    private var ticketScopeKey: String {
        let uid = leagueService.currentUserId ?? "anonymous"
        let leagueId = ActiveLeagueStore.resolve(from: leagueService.myLeagues, selectedId: selectedLeagueId)?.id ?? "no_league"
        return "\(uid)|\(leagueId)"
    }

    private var activeTickets: [UserTicket] {
        TicketStore.loadHistory(from: ticketHistoryData)[ticketScopeKey] ?? []
    }

    private var tabBadges: [BetsyTab: Int] {
        var b: [BetsyTab: Int] = [:]
        if leagueService.pendingArenaInvite != nil {
            b[.play] = 1
        }
        let openCount = activeTickets.filter { !$0.isResultKnown && !$0.isWithdrawn }.count
        if openCount > 0 {
            b[.tickets] = openCount
        }
        return b
    }

    private func avatarImageData(for userId: String) -> Data? {
        let avatars = ProfileAvatarStore.load(from: profileAvatarStoreData)
        if let data = avatars[userId], !data.isEmpty { return data }
        if userId == leagueService.currentUserId, !avatarImageData.isEmpty { return avatarImageData }
        return nil
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DS.bg.ignoresSafeArea()

            // Screen content
            Group {
                switch selectedTab {
                case .home:
                    BetsyHomeScreen(selectedTab: $selectedTab)
                        .environmentObject(leagueService)
                case .play:
                    BetsyPlayScreen(
                        selectedTab: $selectedTab,
                        onBetPlaced: { ticket in
                            appendTicket(ticket)
                            lastPlacedTicket = ticket
                            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                                showBetPlaced = true
                            }
                        }
                    )
                    .environmentObject(leagueService)
                case .league:
                    BetsyLeagueScreen()
                        .environmentObject(leagueService)
                case .tickets:
                    BetsyTicketsScreen(
                        tickets: activeTickets,
                        onUpdateTickets: updateTickets,
                        onSimulateDevDay: simulateDevDay
                    )
                        .environmentObject(leagueService)
                case .profile:
                    BetsyProfileScreen(tickets: activeTickets)
                        .environmentObject(leagueService)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 82)

            // Tab bar always on top
            BetsyTabBar(selected: $selectedTab, badges: tabBadges, onLongPress: { tab in
                guard tab == .profile else { return }
                showDevModeDialog = true
            })
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let invite = leagueService.pendingArenaInvite {
                    ArenaInviteNotification(
                        duel: invite,
                        challengerAvatarImageData: avatarImageData(for: invite.challengerId),
                        opponentAvatarImageData: avatarImageData(for: invite.opponentId)
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedTab = .play
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            NotificationCenter.default.post(name: .betsyOpenArena, object: invite.id)
                        }
                    }
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
                if let msg = leagueService.errorMessage, !msg.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.loss)
                        Text(msg)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.fg)
                            .lineLimit(2)
                        Spacer(minLength: 6)
                        Button { leagueService.errorMessage = nil } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DS.fg2)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cerrar aviso")
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(DS.loss.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                        .stroke(DS.loss.opacity(0.32), lineWidth: 1))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Aviso: \(msg)")
                    .accessibilityAddTraits(.isStaticText)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
                if leagueService.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7).tint(DS.accent)
                        Text("Sincronizando…")
                            .font(.jbMono(11, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(DS.fg2)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(DS.bg1)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(DS.line, lineWidth: 1))
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 56)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85), value: leagueService.pendingArenaInvite?.id)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85), value: leagueService.errorMessage)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: leagueService.isLoading)
        }
        // Dev-mode indicator pill — separate overlay, always centered at top, never covers content
        #if DEBUG
        .overlay(alignment: .top) {
            if isDevModeActive {
                HStack(spacing: 5) {
                    Circle().fill(DS.warn).frame(width: 5, height: 5)
                    Text("DEV MODE")
                        .font(.jbMono(9, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(DS.warn)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(DS.warn.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(DS.warn.opacity(0.35), lineWidth: 1))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isDevModeActive)
            }
        }
        #endif
        // Bet placed full-screen overlay
        .fullScreenCover(isPresented: $showBetPlaced) {
            BetPlacedScreen(
                ticket: lastPlacedTicket,
                onViewTickets: {
                    showBetPlaced = false
                    selectedTab = .tickets
                },
                onContinue: {
                    showBetPlaced = false
                }
            )
        }
        // Dev-mode toggle dialog (DEBUG only — hidden in Release builds)
        #if DEBUG
        .confirmationDialog(
            isDevModeActive
                ? (appLang == .es ? "Modo Dev activo" : "Dev Mode active")
                : (appLang == .es ? "Modo Dev" : "Dev Mode"),
            isPresented: $showDevModeDialog,
            titleVisibility: .visible
        ) {
            if isDevModeActive {
                Button(appLang == .es ? "Desactivar modo Dev" : "Deactivate Dev Mode", role: .destructive) {
                    exitDevMode()
                }
            } else {
                Button(appLang == .es ? "Activar modo Dev" : "Activate Dev Mode") {
                    enterDevMode()
                }
            }
            Button(appLang == .es ? "Cancelar" : "Cancel", role: .cancel) {}
        } message: {
            Text(isDevModeActive
                 ? (appLang == .es
                    ? "Se restaurará tu cuenta de producción. Los datos de dev se conservan."
                    : "Your production account will be restored. Dev data is kept.")
                 : (appLang == .es
                    ? "Activa datos falsos, testers y herramientas de desarrollo."
                    : "Enables fake data, testers and developer tools."))
        }
        #endif
        .onAppear {
            refreshActiveLeagueContext()
            refreshReminderSchedule()
        }
        .onChange(of: selectedLeagueId) { _, _ in
            refreshActiveLeagueContext()
            refreshReminderSchedule()
        }
        .onChange(of: ticketHistoryData) { _, _ in
            refreshReminderSchedule()
        }
        .onChange(of: leagueService.errorMessage) { _, newValue in
            guard let message = newValue, !message.isEmpty else { return }
            UIAccessibility.post(notification: .announcement, argument: message)
            let dismissDelay: TimeInterval = UIAccessibility.isVoiceOverRunning ? 12.0 : 6.0
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) {
                guard leagueService.errorMessage == message else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    leagueService.errorMessage = nil
                }
            }
        }
        .onChange(of: leagueService.pendingArenaInvite?.id) { _, newValue in
            guard let newValue,
                  newValue != lastNotifiedArenaInviteId,
                  let invite = leagueService.pendingArenaInvite else { return }
            lastNotifiedArenaInviteId = newValue
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            let leagueName = ActiveLeagueStore.resolve(from: leagueService.myLeagues, selectedId: selectedLeagueId)?.name
            BetReminderScheduler.notifyChallengeInvite(
                challengerName: invite.challengerName,
                wager: invite.wager,
                leagueName: leagueName
            )
        }
        .onReceive(leagueService.$myLeagues) { _ in refreshActiveLeagueContext() }
        .onReceive(NotificationCenter.default.publisher(for: .betsyAuthChanged)) { _ in
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { selectedTab = .home }
        }
        .onReceive(arenaResolutionTimer) { _ in
            guard isDevModeActive,
                  let league = ActiveLeagueStore.resolve(from: leagueService.myLeagues, selectedId: selectedLeagueId)
            else { return }
            leagueService.resolveArenaDuelsRandomly(leagueId: league.id)
        }
    }

    // MARK: - Dev mode entry / exit

    /// Enter dev mode: saves production state, jumps straight into the app
    /// with a pre-seeded local session — no Firebase, no login screen.
    private func enterDevMode() {
        let ud = UserDefaults.standard

        // 1. Back up production identity so we can restore it on exit
        ud.set(hasSeenOnboarding, forKey: "devModeBackup_hasSeenOnboarding")
        ud.set(hasSeenTour,       forKey: "devModeBackup_hasSeenTour")
        ud.set(displayName,       forKey: "devModeBackup_displayName")
        ud.set(profileEmail,      forKey: "devModeBackup_profileEmail")
        ud.set(selectedLeagueId,  forKey: "devModeBackup_selectedLeagueId")
        ud.set(avatarImageData,   forKey: "devModeBackup_avatarImageData")

        // 2. Activate dev mode + fake sports data
        isDevModeActive = true
        SportsDataDevelopmentConfig.applyDevMode(true)

        // 3. Restore (or set) the dev display name — persists across mode switches
        let savedDevName = ud.string(forKey: "devMode_displayName") ?? ""
        displayName  = savedDevName.isEmpty ? "Dev User" : savedDevName
        profileEmail = ""
        avatarImageData = Data()
        devProfileRaw   = DevProfile.real.rawValue

        // 4. Skip onboarding / tour — go straight to the main UI
        hasSeenOnboarding = true
        hasSeenTour       = true

        // 5. Bootstrap fully local dev session (no Firebase sign-in)
        leagueService.bootstrapDevSession()
    }

    /// Exit dev mode: saves current dev display name, restores production state.
    private func exitDevMode() {
        let ud = UserDefaults.standard

        // Persist dev display name so re-entering remembers it
        ud.set(displayName, forKey: "devMode_displayName")

        // 1. Deactivate dev mode + real data
        isDevModeActive = false
        SportsDataDevelopmentConfig.applyDevMode(false)
        leagueService.setDeveloperProfile(.real)
        devProfileRaw = DevProfile.real.rawValue

        // 2. Restore production identity
        displayName      = ud.string(forKey: "devModeBackup_displayName") ?? ""
        profileEmail     = ud.string(forKey: "devModeBackup_profileEmail") ?? ""
        avatarImageData  = ud.data(forKey:   "devModeBackup_avatarImageData") ?? Data()
        let restoredLeagueId = ud.string(forKey: "devModeBackup_selectedLeagueId") ?? ""

        // 3. Restore onboarding flags BEFORE resetting session so HomeView shows
        //    the right screen immediately
        hasSeenOnboarding = ud.bool(forKey: "devModeBackup_hasSeenOnboarding")
        hasSeenTour       = ud.bool(forKey: "devModeBackup_hasSeenTour")

        // 4. Re-establish production Firebase session
        leagueService.resetSession()
        selectedLeagueId = restoredLeagueId
    }

    // MARK: - Reminder helpers

    private func refreshReminderSchedule() {
        guard notifReminderEnabled else { return }
        let activeLeague = ActiveLeagueStore.resolve(from: leagueService.myLeagues, selectedId: selectedLeagueId)
        let limit = activeLeague?.settings.betsPerActiveDay ?? 0
        let todayCount = activeTickets.filter { Calendar.current.isDate($0.date, inSameDayAs: DevSimulationClock.now()) && !$0.isWithdrawn }.count
        let left = max(limit - todayCount, 0)
        let weekday = Calendar.current.component(.weekday, from: DevSimulationClock.now())
        let withinWindow: Bool = {
            guard let s = activeLeague?.settings else { return true }
            switch s.betWindowPreset {
            case .daily: return true
            case .weekdays: return (2...6).contains(weekday)
            case .weekend: return weekday == 1 || weekday == 7
            case .custom: return s.activeWeekdays.contains(where: { $0.calendarWeekday == weekday })
            }
        }()
        BetReminderScheduler.schedule(
            enabled: notifReminderEnabled,
            hour: notifReminderHour,
            minute: notifReminderMinute,
            leagueName: activeLeague?.name,
            betsLeftToday: left,
            dailyLimit: limit,
            isWithinBetWindow: withinWindow
        )
    }

    private func appendTicket(_ ticket: UserTicket) {
        var history = TicketStore.loadHistory(from: ticketHistoryData)
        var scoped = history[ticketScopeKey] ?? []
        scoped.insert(ticket, at: 0)
        history[ticketScopeKey] = scoped
        ticketHistoryData = TicketStore.saveHistory(history)
    }

    private func updateTickets(_ tickets: [UserTicket]) {
        var history = TicketStore.loadHistory(from: ticketHistoryData)
        history[ticketScopeKey] = tickets
        ticketHistoryData = TicketStore.saveHistory(history)
    }

    private func simulateDevDay() {
        guard isDevModeActive else { return }
        let simulatedNow = DevSimulationClock.advanceDay()
        var history = TicketStore.loadHistory(from: ticketHistoryData)

        for key in Array(history.keys) {
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let userId = parts[0]
            let leagueId = parts[1]
            let tickets = history[key] ?? []
            let result = TicketSettlementEngine.simulate(
                tickets: tickets,
                initialPoints: 0,
                referenceDate: simulatedNow
            )
            if result.didChange {
                history[key] = result.tickets.sorted { $0.date > $1.date }
                if result.pointsDelta != 0 {
                    let displayName = leagueService.membersByLeague[leagueId]?.first(where: { $0.id == userId })?.name ?? userId
                    leagueService.adjustPoints(leagueId: leagueId, delta: result.pointsDelta, forUserId: userId, displayName: displayName)
                }
            }
        }

        ticketHistoryData = TicketStore.saveHistory(history)
        for league in leagueService.myLeagues {
            leagueService.resolveArenaDuelsRandomly(leagueId: league.id)
        }
        ticketHistoryData = UserDefaults.standard.data(forKey: "betsyTicketHistoryDataV2") ?? ticketHistoryData
        DevDataStore.shared.clearAllArenaDailyLimits()
        DevDataStore.shared.pruneExpiredArenas(cutoff: DevSimulationClock.cutoffDate(retentionDays: 3))
        for league in leagueService.myLeagues {
            leagueService.loadMembers(for: league)
            leagueService.listenForArena(leagueId: league.id)
        }
        NotificationCenter.default.post(name: .betsyDevDayAdvanced, object: nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func refreshActiveLeagueContext() {
        guard let league = ActiveLeagueStore.resolve(from: leagueService.myLeagues, selectedId: selectedLeagueId) else { return }
        if selectedLeagueId != league.id {
            selectedLeagueId = league.id
        }
        leagueService.loadMembers(for: league)
        leagueService.listenForArena(leagueId: league.id)
    }
}

private struct ArenaInviteNotification: View {
    let duel: ArenaDuel
    var challengerAvatarImageData: Data? = nil
    var opponentAvatarImageData: Data? = nil
    let onOpen: () -> Void
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    DSAvatar(name: duel.challengerName, size: 48, imageData: challengerAvatarImageData)
                    Circle()
                        .fill(DS.arena)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(DS.bg1, lineWidth: 2))
                        .offset(x: 2, y: -2)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(appLang == .es ? "Reto Arena recibido" : "Arena challenge received")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(DS.fg)
                    Text(appLang == .es
                         ? "\(duel.challengerName) te reta · apuesta \(duel.wager) pts"
                         : "\(duel.challengerName) challenges you · \(duel.wager) pts stake")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.fg2)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                DSAvatar(name: duel.opponentName, size: 34, accent: true, imageData: opponentAvatarImageData)
            }

            Button(action: onOpen) {
                Text(appLang == .es ? "Ver reto" : "View challenge")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(DS.fg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(DS.arena)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(DS.bg1)
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous).stroke(DS.arena.opacity(0.48), lineWidth: 1.2))
        .shadow(color: DS.arena.opacity(0.22), radius: 24, y: 10)
    }
}
