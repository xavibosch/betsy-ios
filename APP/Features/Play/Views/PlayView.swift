import SwiftUI

// MARK: - Play screen root (fake-provider backed)
struct BetsyPlayScreen: View {
    @EnvironmentObject var leagueService: LeagueService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("displayName") private var displayName: String = ""
    @AppStorage("selectedLeagueId") private var selectedLeagueId = ""
    @AppStorage("betsyTicketHistoryDataV2") private var ticketHistoryData: Data = Data()
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @AppStorage("betsyDraftBetDataV1") private var draftBetData: Data = Data()
    @AppStorage("tutorialSeenForUserIdV1") private var tutorialSeenForUserId = ""
    @Binding var selectedTab: BetsyTab
    var onBetPlaced: (UserTicket) -> Void = { _ in }

    @StateObject private var apiManager = APIManager()
    @State private var activeSubTab: SubTab = .bets
    @State private var selectedFilter = "Todos"
    @State private var selectedSelections: [BetSelection] = []
    @State private var stake = 100
    @State private var requestedArenaDuelId: String? = nil
    @State private var requestedMatchKey: String? = nil
    @State private var highlightedMatchKey: String? = nil
    @State private var showLeagueSwitcher = false
    @State private var showPlayTutorial = false

    enum SubTab { case bets, arena }

    private struct DraftBetState: Codable {
        let leagueId: String
        let stake: Int
        let selections: [BetSelection]
    }

    private var activeLeague: FriendLeague? {
        ActiveLeagueStore.resolve(from: leagueService.myLeagues, selectedId: selectedLeagueId)
    }

    private var sportKeys: [String] {
        let keys = activeLeague?.settings.allowedCompetitions.flatMap(\.sportKeys) ?? []
        return Array(Set(keys))
    }

    private var allowedCompetitions: [LeagueCompetition] {
        activeLeague?.settings.allowedCompetitions ?? []
    }

    private var allowedCompetitionsSignature: String {
        allowedCompetitions.map(\.rawValue).sorted().joined(separator: "|")
    }

    private var leagueName: String {
        activeLeague?.name.uppercased() ?? (appLang == .es ? "SIN LIGA" : "NO LEAGUE")
    }

    private var userName: String {
        if leagueService.currentDevProfile != .real {
            return leagueService.currentDevProfile.displayName
        }
        let n = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? (appLang == .es ? "Yo" : "Me") : n
    }

    private var allFilterLabel: String { appLang == .es ? "Todos" : "All" }

    private var filters: [String] {
        [allFilterLabel] + allowedCompetitions.map { $0.title(lang: appLang) }
    }

    private func competition(for filter: String) -> LeagueCompetition? {
        allowedCompetitions.first { $0.rawValue == filter || $0.title(lang: appLang) == filter }
    }

    private var filteredMatches: [Match] {
        // Always restrict to the league's configured sport keys first
        let allowed = Set(sportKeys)
        let leagueMatches = allowed.isEmpty
            ? apiManager.matches
            : apiManager.matches.filter { allowed.contains($0.sportKey) }
        let sorted = leagueMatches.sorted {
            ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture)
        }
        guard selectedFilter != allFilterLabel else { return sorted }
        guard let selectedCompetition = competition(for: selectedFilter) else { return sorted }
        let selectedKeys = Set(selectedCompetition.sportKeys)
        return sorted.filter { selectedKeys.contains($0.sportKey) }
    }

    private var highlightedMatches: [Match] { Array(filteredMatches.prefix(6)) }
    private var activeLeagueId: String { activeLeague?.id ?? "" }

    private var myBalance: Int {
        guard let league = activeLeague,
              let uid = leagueService.currentUserId else { return 0 }
        return leagueService.membersByLeague[league.id]?.first(where: { $0.id == uid })?.points ?? 0
    }

    private var todaysTickets: [UserTicket] {
        guard let leagueId = activeLeague?.id else { return [] }
        let uid = leagueService.currentUserId ?? "anonymous"
        return (TicketStore.loadHistory(from: ticketHistoryData)["\(uid)|\(leagueId)"] ?? [])
            .filter { Calendar.current.isDate($0.date, inSameDayAs: DevSimulationClock.now()) && !$0.isWithdrawn }
    }
    private var dailyLimit: Int { activeLeague?.settings.betsPerActiveDay ?? 0 }
    private var hasReachedDailyLimit: Bool { dailyLimit > 0 && todaysTickets.count >= dailyLimit }
    private var isWithinBetWindow: Bool {
        guard let settings = activeLeague?.settings else { return true }
        let weekday = Calendar.current.component(.weekday, from: DevSimulationClock.now())
        switch settings.betWindowPreset {
        case .daily: return true
        case .weekdays: return (2...6).contains(weekday)
        case .weekend: return weekday == 1 || weekday == 7
        case .custom: return settings.activeWeekdays.contains(where: { $0.calendarWeekday == weekday })
        }
    }
    private var betLockMessage: String? {
        if !isWithinBetWindow {
            switch activeLeague?.settings.betWindowPreset {
            case .weekdays: return appLang == .es ? "Hoy no se apuesta · ventana lunes a viernes" : "No betting today · Monday to Friday window"
            case .weekend:  return appLang == .es ? "Hoy no se apuesta · ventana fin de semana" : "No betting today · weekend window"
            case .custom:   return appLang == .es ? "Hoy no se apuesta · días personalizados de la liga" : "No betting today · custom league days"
            default: return nil
            }
        }
        if hasReachedDailyLimit {
            return appLang == .es
                ? "Has llegado a tu límite de \(dailyLimit) apuesta\(dailyLimit == 1 ? "" : "s") hoy"
                : "You reached your limit of \(dailyLimit) bet\(dailyLimit == 1 ? "" : "s") today"
        }
        return nil
    }

    private var ticketPayout: Int {
        TicketPricingEngine.potentialPayout(
            stake: stake,
            selections: selectedSelections,
            selectedPowerUp: nil
        )
    }

    private var ticketNetProfit: Int {
        TicketPricingEngine.potentialNetProfit(stake: stake, payout: ticketPayout)
    }

    private var canConfirmTicket: Bool {
        !selectedSelections.isEmpty
            && !activeLeagueId.isEmpty
            && stake > 0
            && stake <= myBalance
            && betLockMessage == nil
    }

    private var ticketWarning: String? {
        if activeLeagueId.isEmpty {
            return appLang == .es ? "Crea o únete a una liga antes de apostar." : "Create or join a league before betting."
        }
        if let betLockMessage {
            return betLockMessage
        }
        if stake > myBalance {
            return appLang == .es ? "No tienes saldo suficiente para esta apuesta." : "You do not have enough balance for this bet."
        }
        return nil
    }

    private var canShowPlayTutorial: Bool {
        activeLeague != nil
            && activeSubTab == .bets
            && isWithinBetWindow
            && !highlightedMatches.isEmpty
    }

    var body: some View {
        baseContent
            .onAppear {
                loadSports()
                restoreDraftBetIfNeeded()
                schedulePlayTutorialCheck()
            }
            .onChange(of: selectedLeagueId) { _, _ in
                selectedFilter = allFilterLabel
                selectedSelections = []
                clearDraftBet()
                loadSports(force: true)
                schedulePlayTutorialCheck()
            }
            .onChange(of: appLang) { _, _ in
                selectedFilter = allFilterLabel
            }
            .onChange(of: allowedCompetitionsSignature) { _, _ in
                selectedFilter = allFilterLabel
                selectedSelections = []
                clearDraftBet()
                loadSports(force: true)
            }
            .onChange(of: leagueService.myLeagues.count) { oldCount, newCount in
                // League data loaded from Firebase after onAppear — reload with correct sport keys
                loadSports()
                restoreDraftBetIfNeeded()
                if oldCount == 0 && newCount > 0 {
                    // First league created for this user — force tutorial auto-show
                    tutorialSeenForUserId = ""
                }
                schedulePlayTutorialCheck()
            }
            .onChange(of: activeSubTab) { _, _ in
                maybeShowPlayTutorial()
            }
            .onChange(of: apiManager.matches.count) { _, _ in
                maybeShowPlayTutorial()
            }
            .onChange(of: selectedSelections) { _, _ in
                persistDraftBet()
            }
            .onChange(of: stake) { _, _ in
                persistDraftBet()
            }
            .refreshable { loadSports(force: true) }
            .onReceive(NotificationCenter.default.publisher(for: .betsyTabReset)) { notif in
                guard let tab = notif.object as? BetsyTab, tab == .play else { return }
                selectedSelections = []
                clearDraftBet()
                selectedFilter = allFilterLabel
                activeSubTab = .bets
            }
            .onReceive(NotificationCenter.default.publisher(for: .betsyOpenArena)) { notification in
                if let id = notification.object as? String {
                    requestedArenaDuelId = id
                } else {
                    requestedArenaDuelId = leagueService.pendingArenaInvite?.id
                }
                activeSubTab = .arena
            }
            .onReceive(NotificationCenter.default.publisher(for: .betsyOpenMatch)) { notification in
                guard let key = notification.object as? String else { return }
                activeSubTab = .bets
                selectedFilter = allFilterLabel
                requestedMatchKey = key
                highlightedMatchKey = key
                loadSports(force: false)
            }
            .onReceive(NotificationCenter.default.publisher(for: .betsyDevDayAdvanced)) { _ in
                selectedSelections = []
                clearDraftBet()
                selectedFilter = allFilterLabel
                loadSports(force: true)
                maybeShowPlayTutorial()
            }
    }

    private var baseContent: AnyView {
        AnyView(
            rootContent
                .modifier(PlayTutorialOverlayModifier(isPresented: $showPlayTutorial))
                .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: selectedSelections.count)
        )
    }

    private var rootContent: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                playHeader
                subTabs
                if activeLeague == nil {
                    NoLeaguePlayState(selectedTab: $selectedTab)
                    Spacer()
                } else if activeSubTab == .bets {
                    if !isWithinBetWindow, let league = activeLeague {
                        ScrollView(showsIndicators: false) {
                            BetWindowClosedView(settings: league.settings, activeSubTab: $activeSubTab)
                                .padding(.top, 28)
                        }
                    } else {
                        if let lockMsg = betLockMessage {
                            betLockBanner(text: lockMsg)
                        }
                        filterPills
                        matchList
                        if !selectedSelections.isEmpty {
                            MultiPickTicketTray(
                                selections: selectedSelections,
                                stake: $stake,
                                balance: myBalance,
                                payout: ticketPayout,
                                netProfit: ticketNetProfit,
                                warning: ticketWarning,
                                canConfirm: canConfirmTicket,
                                onRemove: removeSelection,
                                onConfirm: placeMultiPickTicket
                            )
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                            .playTutorialTarget(.ticketTray)
                        }
                    }
                } else {
                    ArenaOverviewScreen(requestedIncomingDuelId: $requestedArenaDuelId)
                        .environmentObject(leagueService)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

        }
    }

    private func loadSports(force: Bool = false) {
        guard !sportKeys.isEmpty else {
            apiManager.matches = []
            return
        }
        apiManager.fetchRealOddsMulti(keys: sportKeys, force: force)
        apiManager.updateScoreTracking(sports: sportKeys)
    }

    private var playHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    guard !leagueService.myLeagues.isEmpty else {
                        selectedTab = .league
                        return
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                    showLeagueSwitcher = true
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(leagueName)
                            .font(.jbMono(11, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(DS.fg3)
                        HStack(spacing: 5) {
                            Text(appLang == .es ? "Jugar" : "Play")
                                .font(.bebas(32))
                                .tracking(-0.5)
                                .foregroundStyle(DS.fg)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(DS.fg3)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            HStack(spacing: 8) {
                if canShowPlayTutorial {
                    tutorialReplayButton
                }
                DSPill(text: "\(highlightedMatches.count) \(appLang == .es ? "hoy" : "today")", bg: DS.accentSoft, border: DS.accentLine, fg: DS.accent, dot: DS.accent)
            }
        }
        .padding(.horizontal, DS.screenHPad)
        .padding(.bottom, 8)
        .sheet(isPresented: $showLeagueSwitcher) {
            LeagueSwitcherSheet(isPresented: $showLeagueSwitcher)
                .environmentObject(leagueService)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var subTabs: some View {
        HStack(spacing: 8) {
            bigSubTabButton(title: appLang == .es ? "Apuestas" : "Bets", icon: "ticket.fill", tab: .bets)
            bigSubTabButton(title: "Arena 1v1", icon: "flame.fill", tab: .arena)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private func betLockBanner(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.warn)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.fg)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(DS.warn.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
            .stroke(DS.warn.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func bigSubTabButton(title: String, icon: String, tab: SubTab) -> some View {
        let active = activeSubTab == tab
        let isArena = tab == .arena
        let badgeCount = isArena && leagueService.pendingArenaInvite != nil ? 1 : 0
        Button { activeSubTab = tab } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(active ? (isArena ? .white : DS.accentInk) : DS.fg2)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(active ? (isArena ? DS.arena : DS.accent) : DS.bg1)
            .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                .stroke(active ? Color.clear : DS.line, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 17, height: 17)
                        .background(DS.arena)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(DS.bg, lineWidth: 2))
                        .offset(x: 8, y: -7)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? .isSelected : [])
        .playTutorialTarget(tab == .bets ? .betsTab : .arenaTab)
    }

    private var tutorialReplayButton: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.easeIn(duration: 0.18)) { showPlayTutorial = true }
        } label: {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DS.accent)
                .frame(width: 44, height: 44)
                .background(DS.accentSoft)
                .clipShape(Circle())
                .overlay(Circle().stroke(DS.accentLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appLang == .es ? "Repetir tutorial" : "Replay tutorial")
    }

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(filters, id: \.self) { f in
                    Button { selectedFilter = f } label: {
                        Text(f)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(selectedFilter == f ? DS.bg : DS.fg2)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(selectedFilter == f ? DS.fg : DS.bg1)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selectedFilter == f ? DS.fg : DS.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .frame(height: 44)
                    .contentShape(Rectangle())
                    .accessibilityAddTraits(selectedFilter == f ? .isSelected : [])
                    .accessibilityValue(selectedFilter == f ? (appLang == .es ? "Seleccionado" : "Selected") : "")
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 44)
        }
        .frame(height: 44)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .clipped()
        .playTutorialTarget(.filters)
        .padding(.bottom, 6)
    }

    private var matchList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if apiManager.isLoadingOdds && apiManager.matches.isEmpty {
                        VStack(spacing: 10) {
                            ProgressView().tint(DS.accent)
                            Text(appLang == .es ? "Cargando partidos…" : "Loading matches…")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DS.fg3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 70)
                    } else if highlightedMatches.isEmpty {
                        EmptySportsState(
                            onReload: { loadSports(force: true) },
                            errorMessage: apiManager.oddsError
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                    } else {
                        DSSectionRow(title: appLang == .es ? "Destacados · hoy" : "Featured · today",
                                     action: appLang == .es ? "Actualizar" : "Refresh") {
                            loadSports(force: true)
                        }
                        VStack(spacing: 10) {
                            let firstMatchKey = highlightedMatches.first.map(matchNavigationKey)
                            ForEach(highlightedMatches) { match in
                                let key = matchNavigationKey(match)
                                PlayMatchCard(
                                    match: match,
                                    selectedOddLabel: selectedOddLabel(for: match),
                                    isHighlighted: highlightedMatchKey == key,
                                    onToggleOdd: { odd in toggleSelection(match: match, odd: odd) }
                                )
                                .id(key)
                                .playTutorialTarget(key == firstMatchKey ? .firstMatch : nil)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, selectedSelections.isEmpty ? 22 : 160)
                    }
                }
            }
            .onAppear { scrollToRequestedMatch(proxy) }
            .onChange(of: requestedMatchKey) { _, _ in scrollToRequestedMatch(proxy) }
            .onChange(of: highlightedMatches.count) { _, _ in
                scrollToRequestedMatch(proxy)
                maybeShowPlayTutorial()
            }
        }
    }

    private func maybeShowPlayTutorial() {
        guard let uid = leagueService.currentUserId, !uid.isEmpty,
              tutorialSeenForUserId != uid,
              canShowPlayTutorial,
              !showPlayTutorial else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard let uid = self.leagueService.currentUserId, !uid.isEmpty,
                  self.tutorialSeenForUserId != uid,
                  self.canShowPlayTutorial,
                  !self.showPlayTutorial else { return }
            self.tutorialSeenForUserId = uid
            withAnimation(.easeIn(duration: 0.22)) { self.showPlayTutorial = true }
        }
    }

    private func schedulePlayTutorialCheck() {
        [0.3, 0.8, 1.6, 2.8, 4.5, 7.0, 10.0].forEach { delay in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                maybeShowPlayTutorial()
            }
        }
    }

    private func matchNavigationKey(_ match: Match) -> String {
        match.eventId ?? "\(match.home)|\(match.away)|\(match.league)"
    }

    private func scrollToRequestedMatch(_ proxy: ScrollViewProxy) {
        guard let key = requestedMatchKey else { return }
        DispatchQueue.main.async {
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86)) {
                proxy.scrollTo(key, anchor: .top)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                guard highlightedMatchKey == key else { return }
                highlightedMatchKey = nil
                requestedMatchKey = nil
            }
        }
    }

    private func selectedOddLabel(for match: Match) -> String? {
        // Match by home+away (stable strings) rather than matchId UUID which regenerates on every load
        selectedSelections.first(where: { $0.home == match.home && $0.away == match.away })?.oddLabel
    }

    private func toggleSelection(match: Match, odd: Odd) {
        guard betLockMessage == nil else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        UISelectionFeedbackGenerator().selectionChanged()
        // Use home+away as stable key — matchId UUID changes every time matches reload
        if let existing = selectedSelections.first(where: { $0.home == match.home && $0.away == match.away && $0.oddLabel == odd.label }) {
            removeSelection(existing)
            return
        }
        selectedSelections.removeAll { $0.home == match.home && $0.away == match.away }
        selectedSelections.append(
            BetSelection(
                matchId: match.id,
                eventId: match.eventId,
                sportKey: match.sportKey,
                home: match.home,
                away: match.away,
                league: match.league,
                startDate: match.startDate,
                oddLabel: odd.label,
                oddValue: odd.value,
                addedAt: DevSimulationClock.now()
            )
        )
    }

    private func removeSelection(_ selection: BetSelection) {
        selectedSelections.removeAll { $0.id == selection.id }
    }

    private func restoreDraftBetIfNeeded() {
        // Always restore — don't bail if selectedSelections is non-empty, since UUIDs in the
        // restored draft will differ from fresh match UUIDs and we rely on home+away matching now.
        guard !activeLeagueId.isEmpty,
              !draftBetData.isEmpty,
              let draft = try? JSONDecoder().decode(DraftBetState.self, from: draftBetData),
              draft.leagueId == activeLeagueId,
              !draft.selections.isEmpty
        else { return }

        selectedSelections = draft.selections
        stake = max(1, draft.stake)
    }

    private func persistDraftBet() {
        guard !activeLeagueId.isEmpty, !selectedSelections.isEmpty else {
            clearDraftBet()
            return
        }

        let draft = DraftBetState(
            leagueId: activeLeagueId,
            stake: max(1, stake),
            selections: selectedSelections
        )
        draftBetData = (try? JSONEncoder().encode(draft)) ?? Data()
    }

    private func clearDraftBet() {
        if !draftBetData.isEmpty {
            draftBetData = Data()
        }
    }

    private func placeMultiPickTicket() {
        guard canConfirmTicket else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let ticket = TicketPricingEngine.makeTicket(
            date: DevSimulationClock.now(),
            selections: selectedSelections,
            stake: stake,
            selectedPowerUp: nil
        )
        leagueService.adjustPoints(leagueId: activeLeagueId, delta: -stake)
        onBetPlaced(ticket)
        selectedSelections = []
        clearDraftBet()
    }
}

private struct PlayTutorialOverlayModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(PlayTutorialTargetPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                if isPresented {
                    PlayTutorialOverlay(
                        isPresented: $isPresented,
                        targetFrames: tutorialFrames(from: anchors, proxy: proxy)
                    )
                    .transition(.opacity)
                    .zIndex(99)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func tutorialFrames(from anchors: [PlayTutorialTarget: Anchor<CGRect>], proxy: GeometryProxy) -> [PlayTutorialTarget: CGRect] {
        var frames: [PlayTutorialTarget: CGRect] = [:]
        for (target, anchor) in anchors {
            frames[target] = proxy[anchor]
        }
        return frames
    }
}

// MARK: - Bet window closed state

private struct BetWindowClosedView: View {
    let settings: LeagueSettings
    @Binding var activeSubTab: BetsyPlayScreen.SubTab
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    private var daysList: String {
        settings.resolvedWeekdays
            .sorted { $0.calendarWeekday < $1.calendarWeekday }
            .map { $0.fullTitle(lang: appLang) }
            .joined(separator: ", ")
    }

    private var windowDescription: String {
        switch settings.betWindowPreset {
        case .daily: return ""
        case .weekdays:
            return appLang == .es
                ? "Esta liga permite apostar de lunes a viernes. Vuelve el próximo día laborable."
                : "This league allows betting Monday to Friday. Come back on the next weekday."
        case .weekend:
            return appLang == .es
                ? "Esta liga está pensada para jugar los fines de semana — viernes, sábado y domingo. Vuelve el viernes."
                : "This league plays on weekends — Friday, Saturday and Sunday. Come back on Friday."
        case .custom:
            return appLang == .es
                ? "Esta liga permite apostar los días: \(daysList)."
                : "This league allows betting on: \(daysList)."
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(DS.bg2).frame(width: 64, height: 64)
                    .overlay(Circle().stroke(DS.line, lineWidth: 1))
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(DS.fg3)
                    .accessibilityHidden(true)
            }
            VStack(spacing: 8) {
                Text(appLang == .es ? "Ventana cerrada" : "Window closed")
                    .font(.bebas(30))
                    .foregroundStyle(DS.fg)
                    .multilineTextAlignment(.center)
                Text(windowDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.fg2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                if settings.challengesOutsideBetWindow {
                    Text(appLang == .es
                         ? "Pero puedes retar a rivales en el Arena hoy."
                         : "But you can challenge rivals in the Arena today.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.arena)
                        .multilineTextAlignment(.center)
                }
            }
            if settings.challengesOutsideBetWindow {
                Button { activeSubTab = .arena } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(appLang == .es ? "Ir al Arena" : "Go to Arena")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(DS.arena)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .dsCard()
        .padding(.horizontal, 20)
    }
}

// MARK: - No league CTA

private struct NoLeaguePlayState: View {
    @Binding var selectedTab: BetsyTab
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(DS.accentSoft).frame(width: 64, height: 64)
                    .overlay(Circle().stroke(DS.accentLine, lineWidth: 1))
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(DS.accent)
            }
            .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(appLang == .es ? "Sin liga\nactiva" : "No active\nleague")
                    .font(.bebas(34))
                    .tracking(-1)
                    .foregroundStyle(DS.fg)
                    .multilineTextAlignment(.center)
                Text(appLang == .es
                     ? "Necesitas una liga para apostar y competir."
                     : "You need a league to bet and compete.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.fg2)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 10) {
                DSButton(title: appLang == .es ? "Crear nueva liga" : "Create new league", style: .primary, fullWidth: true) {
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) { selectedTab = .league }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        NotificationCenter.default.post(name: .betsyOpenCreateLeague, object: nil)
                    }
                }
                DSButton(title: appLang == .es ? "Unirse con código" : "Join with code", style: .ghost, fullWidth: true) {
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) { selectedTab = .league }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        NotificationCenter.default.post(name: .betsyOpenJoinLeague, object: nil)
                    }
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .dsCard()
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

private struct EmptySportsState: View {
    let onReload: () -> Void
    var errorMessage: String? = nil
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    private var hasError: Bool { errorMessage != nil }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: hasError ? "wifi.exclamationmark" : "sportscourt")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(hasError ? DS.warn : DS.fg3)
                .accessibilityHidden(true)
            Text(hasError
                 ? (appLang == .es ? "No se pudieron cargar los partidos" : "Could not load matches")
                 : (appLang == .es ? "No hay mercados disponibles" : "No markets available"))
                .font(.bebas(24))
                .foregroundStyle(DS.fg)
            if let msg = errorMessage {
                Text(msg)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.warn)
                    .multilineTextAlignment(.center)
            } else {
                Text(appLang == .es ? "No hay partidos disponibles ahora mismo. Prueba a actualizar." : "No matches available right now. Try refreshing.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.fg3)
                    .multilineTextAlignment(.center)
            }
            DSButton(title: appLang == .es ? "Actualizar partidos" : "Refresh matches", style: .primary, fullWidth: true, action: onReload)
                .padding(.top, 4)
        }
        .padding(20)
        .dsCard()
    }
}

// MARK: - Match card
struct PlayMatchCard: View {
    let match: Match
    let selectedOddLabel: String?
    var isHighlighted: Bool = false
    let onToggleOdd: (Odd) -> Void
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @AppStorage("isDevModeActive") private var isDevModeActive = false

    private var displayOdds: [Odd] { Array(match.odds.prefix(3)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("\(match.league) · \(matchTime(match.startDate, lang: appLang))")
                    .font(.jbMono(11, weight: .semibold))
                    .foregroundStyle(DS.fg3)
                    .textCase(.uppercase)
                Spacer()
                if let startDate = match.startDate {
                    if startDate <= Date() {
                        DSPill(text: appLang == .es ? "EN VIVO" : "LIVE",
                               bg: DS.loss.opacity(0.15), border: DS.loss.opacity(0.35), fg: DS.loss, fontSize: 10, dot: DS.loss)
                    } else {
                        DSPill(text: appLang == .es ? "PRÓXIMAMENTE" : "SOON",
                               bg: DS.bg2, border: DS.line, fg: DS.fg3, fontSize: 10)
                    }
                }
            }
            HStack(alignment: .center, spacing: 10) {
                Text(match.home)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(DS.fg)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text("VS")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundStyle(DS.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DS.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(DS.accentLine, lineWidth: 1))
                    .accessibilityHidden(true)

                Text(match.away)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(DS.fg)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(match.home) \(appLang == .es ? "contra" : "vs") \(match.away)")
            HStack(spacing: 6) {
                ForEach(displayOdds) { odd in
                    OddsChip(
                        label: odd.label,
                        value: odd.value.oddsText,
                        isActive: selectedOddLabel == odd.label
                    ) {
                        onToggleOdd(odd)
                    }
                }
            }
        }
        .padding(14)
        .dsCard()
        .overlay(
            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                .stroke(isHighlighted ? DS.accent : Color.clear, lineWidth: 2)
        )
    }
}

private struct OddsChip: View {
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    let label: String
    let value: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.jbMono(11, weight: .semibold))
                    .foregroundStyle(isActive ? DS.bg.opacity(0.75) : DS.fg3)
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isActive ? DS.bg : DS.fg)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(isActive ? DS.fg : DS.bg2)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isActive ? DS.fg : DS.line, lineWidth: 1))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44, alignment: .center)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(appLang == .es ? "\(label), cuota \(value)" : "\(label), odds \(value)")
        .accessibilityHint(isActive
                           ? (appLang == .es ? "Seleccionado. Doble toque para quitar" : "Selected. Double tap to remove")
                           : (appLang == .es ? "Doble toque para seleccionar" : "Double tap to select"))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private struct MultiPickTicketTray: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let selections: [BetSelection]
    @Binding var stake: Int
    let balance: Int
    let payout: Int
    let netProfit: Int
    let warning: String?
    let canConfirm: Bool
    let onRemove: (BetSelection) -> Void
    let onConfirm: () -> Void
    @State private var isExpanded = false
    @State private var showStakeEditor = false
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    private var combinedOdds: Double {
        TicketPricingEngine.combinedOdds(for: selections)
    }

    private var firstSelection: BetSelection? { selections.first }
    private var extraCount: Int { max(selections.count - 1, 0) }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                DSPill(text: "\(selections.count) PICK\(selections.count == 1 ? "" : "S")",
                       bg: DS.accentSoft, border: DS.accentLine, fg: DS.accent, fontSize: 10)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(appLang == .es ? "CUOTA TOTAL" : "TOTAL ODDS")
                        .font(.jbMono(11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(DS.fg3)
                    Text(String(format: "%.2f", combinedOdds))
                        .font(.bebas(24))
                        .foregroundStyle(DS.fg)
                }
            }

            if !isExpanded, let firstSelection {
                CompactSelectionRow(selection: firstSelection, extraCount: extraCount) {
                    onRemove(firstSelection)
                }
            }

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(selections) { selection in
                        FullSelectionRow(selection: selection) { onRemove(selection) }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                HStack(spacing: 6) {
                    ForEach([10, 25, 50, 100], id: \.self) { amount in
                        Button { stake = amount } label: {
                            Text("\(amount)")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(stake == amount ? DS.bg : DS.fg2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(stake == amount ? DS.fg : DS.bg2)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(stake == amount ? DS.fg : DS.line, lineWidth: 1))
                                .frame(minHeight: 44, alignment: .center)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityLabel(appLang == .es ? "Apuesta \(amount) puntos" : "Stake \(amount) points")
                        .accessibilityValue(stake == amount
                                            ? (appLang == .es ? "Seleccionado" : "Selected")
                                            : (appLang == .es ? "No seleccionado" : "Not selected"))
                        .accessibilityAddTraits(stake == amount ? .isSelected : [])
                    }
                    Button {
                        showStakeEditor = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(DS.fg)
                            .frame(width: 44, height: 34)
                            .background(DS.bg2)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(DS.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(appLang == .es ? "Editar apuesta" : "Edit bet")
                }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(appLang == .es ? "APUESTA" : "STAKE")
                            .font(.jbMono(11, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(DS.fg3)
                        Text("\(stake)")
                            .font(.bebas(34))
                            .foregroundStyle(stake <= balance ? DS.fg : DS.loss)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(appLang == .es ? "PAGO POTENCIAL" : "POTENTIAL PAYOUT")
                            .font(.jbMono(11, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(DS.fg3)
                        Text("\(payout) pts")
                            .font(.bebas(30))
                            .foregroundStyle(DS.win)
                        Text(appLang == .es ? "+\(netProfit) neto" : "+\(netProfit) net")
                            .font(.jbMono(10, weight: .semibold))
                            .foregroundStyle(DS.win)
                    }
                }

                if let warning {
                    Text(warning)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.warn)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                DSButton(title: appLang == .es ? "Confirmar apuesta →" : "Confirm bet →", style: .primary, fullWidth: true, height: 50) {
                    onConfirm()
                }
                .disabled(!canConfirm)
                .opacity(canConfirm ? 1 : 0.45)
                .accessibilityHint(canConfirm
                                   ? (appLang == .es ? "Confirma esta apuesta de \(selections.count) picks por \(stake) puntos" : "Confirm this \(selections.count) pick bet for \(stake) points")
                                   : (warning ?? (appLang == .es ? "Selecciona al menos una cuota válida y revisa tu saldo" : "Select at least one valid odd and review your balance")))
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.85)) {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .black))
                    .foregroundStyle(DS.fg2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.bg2)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(DS.line2, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appLang == .es ? "Minimizar revisión de apuesta" : "Minimize bet review")
            } else {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appLang == .es ? "Pago potencial" : "Potential payout")
                            .font(.jbMono(11, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(DS.fg3)
                        Text("\(payout) pts")
                            .font(.bebas(24))
                            .foregroundStyle(DS.win)
                    }
                    Spacer()
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.85)) {
                            isExpanded = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(appLang == .es ? "Revisar apuesta" : "Review bet")
                                .font(.system(size: 13, weight: .black))
                            Image(systemName: "chevron.up")
                                .font(.system(size: 11, weight: .black))
                        }
                        .foregroundStyle(DS.accentInk)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(DS.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, isExpanded ? 24 : 14)
        .background(DS.bg1)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(DS.line2, lineWidth: 1))
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    guard isExpanded, value.translation.height > 45 else { return }
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.85)) {
                        isExpanded = false
                    }
                }
        )
        .onChange(of: selections.count) { _, count in
            if count <= 1 { isExpanded = false }
        }
        .sheet(isPresented: $showStakeEditor) {
            StakeEditorSheet(
                stake: $stake,
                balance: balance,
                lang: appLang
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct CompactSelectionRow: View {
    let selection: BetSelection
    let extraCount: Int
    let onRemove: () -> Void
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    var body: some View {
        HStack(spacing: 10) {
            DSCrest(team: teamCode(selection.home), size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(readableOddLabel(selection.oddLabel, home: selection.home, away: selection.away, lang: appLang))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(DS.fg)
                    .lineLimit(1)
                Text("\(selection.home) @ \(selection.oddValue.oddsText)")
                    .font(.jbMono(10, weight: .semibold))
                    .foregroundStyle(DS.fg3)
                    .lineLimit(1)
            }
            Spacer()
            if extraCount > 0 {
                DSPill(text: "+\(extraCount)", bg: DS.bg3, border: DS.line2, fg: DS.fg, fontSize: 10)
            }
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(DS.fg2)
                    .frame(width: 28, height: 28)
                    .background(DS.bg2)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(DS.line, lineWidth: 1))
                    .contentShape(Rectangle().size(CGSize(width: 44, height: 44)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appLang == .es ? "Eliminar selección" : "Remove selection")
        }
        .padding(10)
        .background(DS.bg2)
        .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous).stroke(DS.line, lineWidth: 1))
    }
}

private struct FullSelectionRow: View {
    let selection: BetSelection
    let onRemove: () -> Void
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    var body: some View {
        HStack(spacing: 10) {
            DSCrest(team: teamCode(selection.home), size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selection.home) vs \(selection.away)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.fg)
                    .lineLimit(1)
                Text("\(readableOddLabel(selection.oddLabel, home: selection.home, away: selection.away, lang: appLang)) @ \(selection.oddValue.oddsText)")
                    .font(.jbMono(10, weight: .semibold))
                    .foregroundStyle(DS.fg3)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(DS.fg2)
                    .frame(width: 28, height: 28)
                    .background(DS.bg2)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(DS.line, lineWidth: 1))
                    .contentShape(Rectangle().size(CGSize(width: 44, height: 44)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appLang == .es ? "Eliminar selección" : "Remove selection")
        }
        .padding(10)
        .background(DS.bg2)
        .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous).stroke(DS.line, lineWidth: 1))
    }
}

private struct StakeEditorSheet: View {
    @Binding var stake: Int
    let balance: Int
    let lang: AppLang
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    private var parsedValue: Int {
        Int(draft) ?? 0
    }

    private var canApply: Bool {
        parsedValue > 0 && parsedValue <= max(balance, 0)
    }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lang == .es ? "APUESTA MANUAL" : "CUSTOM STAKE")
                            .font(.jbMono(10, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(DS.fg3)
                        Text(lang == .es ? "Elige puntos" : "Choose points")
                            .font(.bebas(34))
                            .foregroundStyle(DS.fg)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(DS.fg)
                            .frame(width: 44, height: 44)
                            .background(DS.bg2)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(DS.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 6) {
                    Text(draft.isEmpty ? "0" : draft)
                        .font(.bebas(56))
                        .foregroundStyle(canApply || draft.isEmpty ? DS.fg : DS.loss)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(DS.bg1)
                        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous).stroke(canApply || draft.isEmpty ? DS.line : DS.loss.opacity(0.55), lineWidth: 1))

                    Text(lang == .es ? "Saldo disponible: \(balance) pts" : "Available balance: \(balance) pts")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(canApply || draft.isEmpty ? DS.fg3 : DS.loss)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(1...9, id: \.self) { number in
                        keypadButton("\(number)") { appendDigit(number) }
                    }
                    keypadButton("⌫", keyLabel: lang == .es ? "Borrar dígito" : "Delete digit") { deleteDigit() }
                    keypadButton("0") { appendDigit(0) }
                    keypadButton(lang == .es ? "OK" : "OK", isPrimary: true) { apply() }
                        .disabled(!canApply)
                        .opacity(canApply ? 1 : 0.45)
                }
            }
            .padding(20)
        }
        .onAppear {
            draft = stake > 0 ? "\(stake)" : ""
        }
    }

    private func keypadButton(_ title: String, isPrimary: Bool = false, keyLabel: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(isPrimary ? DS.accentInk : DS.fg)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isPrimary ? DS.accent : DS.bg2)
                .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous).stroke(isPrimary ? DS.accent : DS.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(keyLabel ?? title)
    }

    private func appendDigit(_ digit: Int) {
        guard draft.count < 6 else { return }
        if draft == "0" { draft = "" }
        draft.append("\(digit)")
    }

    private func deleteDigit() {
        guard !draft.isEmpty else { return }
        draft.removeLast()
    }

    private func apply() {
        guard canApply else { return }
        stake = parsedValue
        dismiss()
    }
}

// MARK: - Match detail + Bet slip sheet
struct MatchDetailSheet: View {
    let match: Match
    var onBetPlaced: (UserTicket) -> Void = { _ in }

    @EnvironmentObject var leagueService: LeagueService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLeagueId") private var selectedLeagueId = ""
    @AppStorage("betsyTicketHistoryDataV2") private var ticketHistoryData: Data = Data()
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @State private var selectedOdd: Odd? = nil
    @State private var stake: Int = 100
    @State private var showStakeEditor = false

    private var activeLeague: FriendLeague? {
        ActiveLeagueStore.resolve(from: leagueService.myLeagues, selectedId: selectedLeagueId)
    }
    private var activeLeagueId: String { activeLeague?.id ?? "" }

    private var myBalance: Int {
        guard let league = activeLeague,
              let uid = leagueService.currentUserId else { return 0 }
        return leagueService.membersByLeague[league.id]?.first(where: { $0.id == uid })?.points ?? 0
    }

    private var potentialPayout: Int {
        guard let odd = selectedOdd else { return 0 }
        return Int((Double(stake) * odd.value).rounded())
    }

    private var netProfit: Int { max(potentialPayout - stake, 0) }
    private var todaysTickets: [UserTicket] {
        guard !activeLeagueId.isEmpty else { return [] }
        let uid = leagueService.currentUserId ?? "anonymous"
        let key = "\(uid)|\(activeLeagueId)"
        return (TicketStore.loadHistory(from: ticketHistoryData)[key] ?? [])
            .filter { Calendar.current.isDate($0.date, inSameDayAs: DevSimulationClock.now()) && !$0.isWithdrawn }
    }
    private var dailyLimit: Int { activeLeague?.settings.betsPerActiveDay ?? 0 }
    private var remainingBetsToday: Int { max(dailyLimit - todaysTickets.count, 0) }
    private var hasReachedDailyLimit: Bool { dailyLimit > 0 && remainingBetsToday <= 0 }
    private var isWithinBetWindow: Bool {
        guard let settings = activeLeague?.settings else { return true }
        let weekday = Calendar.current.component(.weekday, from: DevSimulationClock.now())
        switch settings.betWindowPreset {
        case .daily:
            return true
        case .weekdays:
            return (2...6).contains(weekday) // Mon–Fri
        case .weekend:
            return weekday == 1 || weekday == 7 // Sun or Sat
        case .custom:
            return settings.activeWeekdays.contains(where: { $0.calendarWeekday == weekday })
        }
    }
    private var betWindowMessage: String {
        guard let settings = activeLeague?.settings else { return "" }
        switch settings.betWindowPreset {
        case .daily: return ""
        case .weekdays: return appLang == .es ? "Esta liga solo permite apostar de lunes a viernes." : "This league only allows betting from Monday to Friday."
        case .weekend: return appLang == .es ? "Esta liga solo permite apostar sábado y domingo." : "This league only allows betting on Saturday and Sunday."
        case .custom:
            let days = settings.activeWeekdays
                .sorted { $0.calendarWeekday < $1.calendarWeekday }
                .map { $0.shortTitle(lang: appLang) }
                .joined(separator: " · ")
            return appLang == .es ? "Esta liga solo permite apostar: \(days)" : "This league only allows betting on: \(days)"
        }
    }
    private var canConfirm: Bool {
        selectedOdd != nil && !activeLeagueId.isEmpty && stake > 0 && stake <= myBalance && !hasReachedDailyLimit && isWithinBetWindow
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    sheetHeader

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            matchHero
                                .padding(.horizontal, 20).padding(.bottom, 16)

                            DSSectionRow(title: appLang == .es ? "Ganador" : "Winner")
                            HStack(spacing: 8) {
                                ForEach(match.odds.prefix(3)) { odd in
                                    marketOdd(odd)
                                }
                            }
                            .padding(.horizontal, 20)

                            if !match.markets.dropFirst().isEmpty {
                                ForEach(match.markets.dropFirst().prefix(2)) { market in
                                    DSSectionRow(title: market.name)
                                    HStack(spacing: 8) {
                                        ForEach(market.outcomes.prefix(2)) { odd in
                                            smallOdd(odd)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }

                            Color.clear.frame(height: selectedOdd == nil ? 32 : 210)
                        }
                    }
                }

                if selectedOdd != nil {
                    VStack {
                        Spacer()
                        betSlip
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: selectedOdd?.id)
            .navigationBarHidden(true)
        }
        .onAppear {
            if selectedOdd == nil {
                selectedOdd = match.odds.first
            }
            stake = min(max(10, stake), max(myBalance, 10))
        }
    }

    private var sheetHeader: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.fg)
                    .dsBackButton()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appLang == .es ? "Volver" : "Back")
            Spacer()
                    Text("\(match.league) · \(matchTime(match.startDate, lang: appLang))")
                .font(.jbMono(11, weight: .semibold))
                .foregroundStyle(DS.fg3)
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(DS.accent)
                .dsBackButton()
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var matchHero: some View {
        ZStack {
            LinearGradient(colors: [DS.bg2, DS.bg1], startPoint: .topLeading, endPoint: .bottomTrailing)
            HStack {
                VStack(spacing: 6) {
                    DSCrest(team: teamCode(match.home), size: 56)
                    Text(match.home).font(.bebas(14)).foregroundStyle(DS.fg).minimumScaleFactor(0.75)
                    Text(appLang == .es ? "Local" : "Home").font(.jbMono(11, weight: .semibold)).foregroundStyle(DS.fg3)
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 4) {
                    Text("vs").font(.jbMono(11, weight: .semibold)).foregroundStyle(DS.fg3)
                    Text(matchTime(match.startDate, lang: appLang)).font(.bebas(28)).foregroundStyle(DS.fg3)
                }
                VStack(spacing: 6) {
                    DSCrest(team: teamCode(match.away), size: 56)
                    Text(match.away).font(.bebas(14)).foregroundStyle(DS.fg).minimumScaleFactor(0.75)
                    Text(appLang == .es ? "Visitante" : "Away").font(.jbMono(11, weight: .semibold)).foregroundStyle(DS.fg3)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous).stroke(DS.line, lineWidth: 1))
    }

    @ViewBuilder
    private func marketOdd(_ odd: Odd) -> some View {
        let isSelected = selectedOdd?.id == odd.id
        Button {
            UIImpactFeedbackGenerator(style: isSelected ? .soft : .medium).impactOccurred()
            selectedOdd = isSelected ? nil : odd
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(readableOddLabel(odd.label, home: match.home, away: match.away, lang: appLang).uppercased())
                    .font(.jbMono(11, weight: .semibold))
                    .foregroundStyle(isSelected ? DS.bg.opacity(0.75) : DS.fg3)
                    .lineLimit(1)
                Text(odd.value.oddsText)
                    .font(.bebas(22))
                    .foregroundStyle(isSelected ? DS.bg : DS.fg)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 14)
            .background(isSelected ? DS.fg : DS.bg2)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? DS.fg : DS.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(readableOddLabel(odd.label, home: match.home, away: match.away, lang: appLang)), cuota \(odd.value.oddsText)")
        .accessibilityHint(isSelected ? "Seleccionado. Doble toque para quitar" : "Doble toque para seleccionar")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func smallOdd(_ odd: Odd) -> some View {
        Button { selectedOdd = odd } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(odd.label)
                    .font(.jbMono(11, weight: .semibold)).foregroundStyle(DS.fg3)
                    .lineLimit(1)
                Text(odd.value.oddsText).font(.bebas(18)).foregroundStyle(DS.fg)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(DS.bg2)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(DS.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(odd.label), cuota \(odd.value.oddsText)")
        .accessibilityHint("Doble toque para seleccionar")
    }

    private var betSlip: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    DSPill(text: "BOLETO",
                           bg: DS.accentSoft, border: DS.accentLine, fg: DS.accent, fontSize: 10)
                    if let odd = selectedOdd {
                        Text("\(readableOddLabel(odd.label, home: match.home, away: match.away, lang: appLang)) @ \(odd.value.oddsText)")
                            .font(.jbMono(11, weight: .semibold))
                            .foregroundStyle(DS.fg3)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(appLang == .es ? "Saldo \(myBalance)" : "Balance \(myBalance)")
                    .font(.jbMono(11, weight: .semibold))
                    .foregroundStyle(stake <= myBalance ? DS.fg3 : DS.loss)
            }

            HStack(spacing: 6) {
                ForEach([10, 25, 50, 100], id: \.self) { amount in
                    Button { stake = min(amount, max(myBalance, 0)) } label: {
                        Text("\(amount)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(stake == amount ? DS.bg : DS.fg2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(stake == amount ? DS.fg : DS.bg2)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(stake == amount ? DS.fg : DS.line, lineWidth: 1))
                            .frame(minHeight: 44, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .disabled(myBalance <= 0)
                    .accessibilityLabel(appLang == .es ? "Apuesta \(amount) puntos" : "Stake \(amount) points")
                    .accessibilityValue(stake == amount
                                        ? (appLang == .es ? "Seleccionado" : "Selected")
                                        : (appLang == .es ? "No seleccionado" : "Not selected"))
                    .accessibilityAddTraits(stake == amount ? .isSelected : [])
                }
                Button {
                    showStakeEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(DS.fg)
                        .frame(width: 44, height: 34)
                        .background(DS.bg2)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(DS.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(myBalance <= 0)
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    DSEyebrow(text: appLang == .es ? "Apuesta" : "Stake")
                    Text("\(stake)")
                        .font(.bebas(44)).tracking(-2).foregroundStyle(DS.fg)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    DSEyebrow(text: appLang == .es ? "Pago potencial" : "Potential payout")
                    Text("\(potentialPayout)")
                        .font(.bebas(36)).tracking(-1).foregroundStyle(DS.win)
                    Text(appLang == .es ? "+\(netProfit) neto" : "+\(netProfit) net")
                        .font(.jbMono(11, weight: .semibold))
                        .foregroundStyle(DS.win)
                }
            }

            if activeLeagueId.isEmpty {
                Text(appLang == .es ? "Crea o únete a una liga antes de apostar." : "Create or join a league before betting.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.warn)
            } else if !isWithinBetWindow {
                Text(betWindowMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.warn)
            } else if hasReachedDailyLimit {
                Text(appLang == .es ? "No puedes apostar más hoy: esta liga permite \(dailyLimit) apuesta\(dailyLimit == 1 ? "" : "s") al día." : "You cannot bet more today: this league allows \(dailyLimit) bet\(dailyLimit == 1 ? "" : "s") per day.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.warn)
            } else if stake > myBalance {
                Text(appLang == .es ? "No tienes saldo suficiente para esta apuesta." : "You do not have enough balance for this stake.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.loss)
            }

            DSButton(title: appLang == .es ? "Confirmar apuesta →" : "Confirm bet →", style: .primary, fullWidth: true, height: 52) {
                placeBet()
            }
            .disabled(!canConfirm)
            .opacity(canConfirm ? 1 : 0.45)
            .accessibilityHint(canConfirm ? "Confirma la apuesta por \(stake) puntos" : disabledConfirmReason)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 34)
        .background(DS.bg1)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(DS.line2, lineWidth: 1))
        .sheet(isPresented: $showStakeEditor) {
            StakeEditorSheet(
                stake: $stake,
                balance: myBalance,
                lang: appLang
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var disabledConfirmReason: String {
        if selectedOdd == nil { return appLang == .es ? "Selecciona una cuota para continuar" : "Select odds to continue" }
        if activeLeagueId.isEmpty { return appLang == .es ? "Crea o únete a una liga antes de apostar" : "Create or join a league before betting" }
        if !isWithinBetWindow { return betWindowMessage }
        if hasReachedDailyLimit { return appLang == .es ? "Has usado tus \(dailyLimit) apuestas de hoy" : "You used your \(dailyLimit) bets today" }
        if stake > myBalance { return appLang == .es ? "No tienes saldo suficiente" : "You do not have enough balance" }
        return appLang == .es ? "Revisa la apuesta antes de continuar" : "Review the bet before continuing"
    }

    private func placeBet() {
        guard canConfirm, let odd = selectedOdd else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let selection = BetSelection(
            matchId: match.id,
            eventId: match.eventId,
            sportKey: match.sportKey,
            home: match.home,
            away: match.away,
            league: match.league,
            startDate: match.startDate,
            oddLabel: odd.label,
            oddValue: odd.value,
            addedAt: DevSimulationClock.now()
        )
        let ticket = UserTicket(
            date: DevSimulationClock.now(),
            selections: [selection],
            stake: stake,
            potentialPayout: potentialPayout,
            potentialNetProfit: netProfit
        )
        leagueService.adjustPoints(leagueId: activeLeagueId, delta: -stake)
        onBetPlaced(ticket)
        dismiss()
    }
}

// MARK: - Bet Placed Screen
struct BetPlacedScreen: View {
    let ticket: UserTicket?
    let onViewTickets: () -> Void
    let onContinue: () -> Void
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    private var firstSelection: BetSelection? { ticket?.selections.first }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            Circle().fill(DS.accent.opacity(0.18)).frame(width: 300).blur(radius: 80)
            DSArenaGrid(opacity: 0.25)

            VStack(spacing: 0) {
                HStack {
                    Text(appLang == .es ? "CONFIRMACIÓN" : "CONFIRMATION")
                        .font(.jbMono(11, weight: .semibold))
                        .tracking(2).foregroundStyle(DS.fg3)
                        .accessibilityLabel(appLang == .es ? "Confirmación" : "Confirmation")
                    Spacer()
                    Button { onContinue() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.fg)
                            .dsBackButton()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.top, 70)

                Spacer()

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(DS.accent)
                            .frame(width: 96, height: 96)
                            .shadow(color: DS.accent.opacity(0.5), radius: 40)
                        Image(systemName: "checkmark")
                            .font(.bebas(40))
                            .foregroundStyle(DS.accentInk)
                            .accessibilityHidden(true)
                    }

                    VStack(spacing: 8) {
                        Text(appLang == .es ? "¡APUESTA CREADA!" : "BET PLACED!")
                            .font(.jbMono(11, weight: .semibold))
                            .tracking(2).foregroundStyle(DS.fg3)
                            .accessibilityLabel(appLang == .es ? "¡Apuesta creada!" : "Bet placed!")
                        VStack(spacing: 0) {
                            Text(appLang == .es ? "Apuesta" : "Bet")
                                .font(.bebas(48)).tracking(-2).foregroundStyle(DS.fg)
                            HStack(spacing: 0) {
                                Text(appLang == .es ? "en juego" : "is live")
                                    .font(.bebas(48)).tracking(-2).foregroundStyle(DS.fg)
                                Text(".")
                                    .font(.bebas(48)).tracking(-2).foregroundStyle(DS.accent)
                            }
                        }
                    }

                    VStack(spacing: 0) {
                        receiptRow(appLang == .es ? "Pick" : "Pick", value: pickText)
                        Divider().background(DS.line)
                        receiptRow(appLang == .es ? "Cuota" : "Odds", value: "@ \(firstSelection?.oddValue.oddsText ?? "—")")
                        receiptRow(appLang == .es ? "Apuesta" : "Stake", value: "\(ticket?.stake ?? 0) pts")
                        receiptRow(appLang == .es ? "Si gana" : "If it wins", value: "+\(ticket?.potentialNetProfit ?? 0) pts",
                                   valueColor: DS.win)
                    }
                    .dsCard()
                    .padding(.horizontal, 28)
                }

                Spacer()

                VStack(spacing: 10) {
                    DSButton(title: appLang == .es ? "Ver mis apuestas" : "View my bets", style: .primary, fullWidth: true) {
                        onViewTickets()
                    }
                    DSButton(title: appLang == .es ? "Seguir apostando" : "Keep betting", style: .ghost, fullWidth: true) {
                        onContinue()
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }

    private var pickText: String {
        guard let selection = firstSelection else { return appLang == .es ? "Pick pendiente" : "Pending pick" }
        let readable = readableOddLabel(selection.oddLabel, home: selection.home, away: selection.away, lang: appLang)
        return "\(readable) · \(selection.home) vs \(selection.away)"
    }

    private func receiptRow(_ label: String, value: String, valueColor: Color = DS.fg) -> some View {
        HStack {
            Text(label)
                .font(.jbMono(11, weight: .semibold))
                .tracking(1.5).foregroundStyle(DS.fg3)
            Spacer()
            Text(value)
                .font(.bebas(16)).foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }
}

// MARK: - Formatting helpers
private func matchTime(_ date: Date?, lang: AppLang = .es) -> String {
    guard let date else { return lang == .es ? "HOY" : "TODAY" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: lang == .es ? "es_ES" : "en_US")
    formatter.dateFormat = Calendar.current.isDateInToday(date)
        ? (lang == .es ? "'HOY' HH:mm" : "'TODAY' HH:mm")
        : "EEE HH:mm"
    return formatter.string(from: date)
}

private func teamCode(_ name: String) -> String {
    let words = name
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
    if words.count >= 2 {
        return words.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
    return String(name.prefix(3)).uppercased()
}

private extension Double {
    var oddsText: String {
        String(format: "%.2f", self)
    }
}
