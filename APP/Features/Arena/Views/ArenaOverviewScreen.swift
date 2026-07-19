import SwiftUI

// MARK: - Arena Overview (ScreenArenaOverview)
struct ArenaOverviewScreen: View {
    @EnvironmentObject var leagueService: LeagueService
    @AppStorage("selectedLeagueId") private var selectedLeagueId = ""
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @AppStorage("profileAvatarImageData") private var legacyAvatarImageData: Data = Data()
    @AppStorage("betsyProfileAvatarStoreDataV1") private var profileAvatarStoreData: Data = Data()
    @Binding var requestedIncomingDuelId: String?
    @State private var showCreate = false
    @State private var selectedDuel: ArenaDuel? = nil
    @State private var selectedIncomingDuel: ArenaDuel? = nil

    private var activeLeague: FriendLeague? {
        ActiveLeagueStore.resolve(from: leagueService.myLeagues, selectedId: selectedLeagueId)
    }

    private var currentUserId: String {
        leagueService.currentUserId ?? ""
    }

    private var visibleDuels: [ArenaDuel] {
        guard let leagueId = activeLeague?.id else { return [] }
        return (leagueService.arenasByLeague[leagueId] ?? []).sorted { lhs, rhs in
            let lp = duelPriority(lhs)
            let rp = duelPriority(rhs)
            if lp != rp { return lp < rp }
            return (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
        }
    }

    private func avatarImageData(for userId: String) -> Data? {
        let avatars = ProfileAvatarStore.load(from: profileAvatarStoreData)
        if let data = avatars[userId], !data.isEmpty { return data }
        if userId == leagueService.currentUserId, !legacyAvatarImageData.isEmpty { return legacyAvatarImageData }
        return nil
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Arena hero card
                ZStack {
                    DSArenaGrid(opacity: 0.4)
                    LinearGradient(
                        colors: [Color(dsHex: "ff2d55"), Color(dsHex: "ff8a2d")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    VStack(alignment: .leading, spacing: 0) {
                        DSPill(text: appLang == .es ? "ARENA 1V1 · EN VIVO" : "ARENA 1V1 · LIVE",
                               bg: .black.opacity(0.3), border: .white.opacity(0.2),
                               fg: .white, fontSize: 10, dot: DS.arena)
                        Text(appLang == .es ? "Reta a quien\nquieras.\nGana por cuota." : "Challenge\nanyone.\nWin by odds.")
                            .font(.bebas(36)).tracking(-1)
                            .foregroundStyle(.white)
                            .padding(.top, 16)
                        Button { showCreate = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12)).foregroundStyle(DS.arena)
                                Text(appLang == .es ? "Lanzar nuevo reto" : "Launch new challenge")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.black.opacity(0.85))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 22)
                    }
                    .padding(22)
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

                DSSectionRow(title: appLang == .es ? "Tus duelos" : "Your duels")
                VStack(spacing: 10) {
                    if visibleDuels.isEmpty {
                        ArenaEmptyState()
                    } else {
                        ForEach(visibleDuels) { duel in
                            Button {
                                if duel.status == "pending", duel.opponentId == currentUserId {
                                    selectedIncomingDuel = duel
                                } else if duel.status == "active" {
                                    selectedDuel = duel
                                }
                            } label: {
                                RealArenaStatusCard(
                                    duel: duel,
                                    stateText: stateText(for: duel),
                                    tint: tint(for: duel),
                                    currentUserId: currentUserId,
                                    challengerAvatarImageData: avatarImageData(for: duel.challengerId),
                                    opponentAvatarImageData: avatarImageData(for: duel.opponentId)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(duel.status != "pending" && duel.status != "active")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            if let league = activeLeague {
                leagueService.loadMembers(for: league)
                leagueService.listenForArena(leagueId: league.id)
            }
            openRequestedIncomingDuelIfNeeded()
        }
        .onChange(of: requestedIncomingDuelId) { _, _ in
            openRequestedIncomingDuelIfNeeded()
        }
        .onChange(of: leagueService.pendingArenaInvite?.id) { _, _ in
            openRequestedIncomingDuelIfNeeded()
        }
        .fullScreenCover(isPresented: $showCreate) {
            ArenaCreateScreen()
                .environmentObject(leagueService)
        }
        .fullScreenCover(item: $selectedDuel) { duel in
            ArenaDuelPickScreen(duel: duel, leagueService: leagueService)
        }
        .fullScreenCover(item: $selectedIncomingDuel) { duel in
            ArenaIncomingScreen(duel: duel, leagueService: leagueService)
        }
    }

    private func duelPriority(_ duel: ArenaDuel) -> Int {
        if duel.status == "pending", duel.opponentId == currentUserId { return 0 }
        if duel.status == "pending", duel.challengerId == currentUserId { return 1 }
        if duel.status == "active" { return 2 }
        if duel.status == "declined" { return 3 }
        if duel.status == "resolved" { return 4 }
        return 5
    }

    private func stateText(for duel: ArenaDuel) -> String {
        if duel.status == "pending", duel.opponentId == currentUserId { return appLang == .es ? "RETO ENTRANTE · TOCA PARA VER" : "INCOMING CHALLENGE · TAP TO VIEW" }
        if duel.status == "pending", duel.challengerId == currentUserId { return appLang == .es ? "ESPERANDO RESPUESTA" : "WAITING FOR RESPONSE" }
        if duel.status == "active" {
            let mine = duel.challengerId == currentUserId ? duel.challengerSelections : duel.opponentSelections
            return mine.isEmpty
                ? (appLang == .es ? "EN JUEGO · FALTA TU PICK" : "IN PLAY · YOUR PICK NEEDED")
                : (appLang == .es ? "EN JUEGO · ESPERANDO RESULTADO" : "IN PLAY · WAITING FOR RESULT")
        }
        if duel.status == "declined" { return appLang == .es ? "RETO RECHAZADO" : "CHALLENGE DECLINED" }
        if duel.status == "resolved" {
            if duel.winnerId == currentUserId || duel.winnerId == "both" { return appLang == .es ? "VICTORIA ARENA" : "ARENA WIN" }
            if duel.loserId == currentUserId { return appLang == .es ? "DERROTA ARENA" : "ARENA LOSS" }
            return appLang == .es ? "EMPATE ARENA" : "ARENA DRAW"
        }
        return duel.status.uppercased()
    }

    private func tint(for duel: ArenaDuel) -> Color {
        if duel.status == "pending", duel.opponentId == currentUserId { return DS.arena }
        if duel.status == "pending" { return DS.warn }
        if duel.status == "active" { return DS.accent }
        if duel.status == "declined" { return DS.loss }
        if duel.status == "resolved" {
            if duel.winnerId == currentUserId || duel.winnerId == "both" { return DS.win }
            if duel.loserId == currentUserId { return DS.loss }
            return DS.warn
        }
        return DS.fg2
    }

    private func openRequestedIncomingDuelIfNeeded() {
        guard let requestedIncomingDuelId else { return }
        let candidates = visibleDuels + [leagueService.pendingArenaInvite].compactMap { $0 }
        guard let duel = candidates.first(where: { $0.id == requestedIncomingDuelId && $0.opponentId == currentUserId }) else { return }
        selectedIncomingDuel = duel
        self.requestedIncomingDuelId = nil
    }
}

private struct ArenaEmptyState: View {
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.horizontal")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(DS.fg3)
            Text(appLang == .es ? "Sin duelos activos" : "No active duels")
                .font(.bebas(24))
                .foregroundStyle(DS.fg)
            Text(appLang == .es ? "Lanza un reto a un miembro de tu liga para probar el flujo completo." : "Challenge a league member to test the full flow.")
                .font(.system(size: 12))
                .foregroundStyle(DS.fg3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .dsCard()
    }
}

private struct RealArenaStatusCard: View {
    let duel: ArenaDuel
    let stateText: String
    let tint: Color
    var currentUserId: String = ""
    var challengerAvatarImageData: Data? = nil
    var opponentAvatarImageData: Data? = nil
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    private var isResolved: Bool {
        duel.status == "resolved"
    }

    private var isWin: Bool {
        duel.winnerId == currentUserId || duel.winnerId == "both"
    }

    private var isLoss: Bool {
        duel.loserId == currentUserId
    }

    private var resultTitle: String {
        guard isResolved else { return stateText }
        if isWin { return appLang == .es ? "VICTORIA" : "VICTORY" }
        if isLoss { return appLang == .es ? "DERROTA" : "DEFEAT" }
        return appLang == .es ? "EMPATE" : "DRAW"
    }

    private var resultIcon: String {
        if isResolved {
            if isWin { return "checkmark.circle.fill" }
            if isLoss { return "xmark.circle.fill" }
            return "minus.circle.fill"
        }
        return "bolt.circle.fill"
    }

    private var pointsText: String {
        if isResolved {
            if isWin { return "+\(duel.wager) PTS" }
            if isLoss { return "-\(duel.wager) PTS" }
            return "0 PTS"
        }
        return "\(duel.wager) PTS"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: resultIcon)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)

                Text(resultTitle)
                    .font(.bebas(isResolved ? 34 : 26))
                    .tracking(-0.6)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer()

                Text(pointsText)
                    .font(.jbMono(17, weight: .black))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }

            HStack(spacing: 14) {
                VStack(spacing: 7) {
                    DSAvatar(
                        name: duel.challengerName,
                        size: 46,
                        accent: duel.challengerId == currentUserId,
                        imageData: challengerAvatarImageData
                    )

                    Text(duel.challengerName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DS.fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)

                Text("VS")
                    .font(.jbMono(16, weight: .black))
                    .foregroundStyle(DS.fg3)
                    .padding(.horizontal, 2)

                VStack(spacing: 7) {
                    DSAvatar(
                        name: duel.opponentName,
                        size: 46,
                        accent: duel.opponentId == currentUserId,
                        imageData: opponentAvatarImageData
                    )

                    Text(duel.opponentName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DS.fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(
            ZStack {
                DS.bg1
                LinearGradient(
                    colors: [tint.opacity(isResolved ? 0.18 : 0.10), DS.bg1.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                .stroke(tint.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Arena Create Screen (ScreenArenaCreate)
struct ArenaCreateScreen: View {
    @EnvironmentObject var leagueService: LeagueService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedLeagueId") private var selectedLeagueId = ""
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @AppStorage("isDevModeActive") private var isDevModeActive = false
    @StateObject private var apiManager = APIManager()
    @State private var selectedStake: Int = 50
    @State private var showSent = false
    @State private var showStakeEditor = false
    @State private var selectedOpponentId: String? = nil
    @State private var selectedMatchId: UUID? = nil
    @State private var selectedOddId: String? = nil
    @State private var selectedOddsByMatchId: [String: String] = [:]
    @AppStorage("profileAvatarImageData") private var legacyAvatarImageData: Data = Data()
    @AppStorage("betsyProfileAvatarStoreDataV1") private var profileAvatarStoreData: Data = Data()

    private var myBalance: Int {
        guard let league = activeLeague,
              let uid = leagueService.currentUserId else { return 0 }
        return leagueService.membersByLeague[league.id]?.first(where: { $0.id == uid })?.points ?? 0
    }

    private var activeLeague: FriendLeague? {
        ActiveLeagueStore.resolve(from: leagueService.myLeagues, selectedId: selectedLeagueId)
    }
    private var leagueMembers: [LeagueMember] {
        guard let league = activeLeague, let uid = leagueService.currentUserId else { return [] }
        return (leagueService.membersByLeague[league.id] ?? []).filter { $0.id != uid }
    }
    private var selectedOpponent: LeagueMember? {
        leagueMembers.first(where: { $0.id == selectedOpponentId }) ?? leagueMembers.first
    }
    private var availableMatches: [Match] {
        apiManager.matches
            .filter { ($0.startDate ?? .distantPast) > DevSimulationClock.now() }
            .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
    }
    private var assignedMatches: [Match] {
        Array(availableMatches.prefix(3))
    }
    private var selectedArenaSelections: [ArenaBetSelection] {
        assignedMatches.compactMap { match in
            let matchId = match.eventId ?? match.id.uuidString
            guard let oddId = selectedOddsByMatchId[matchId],
                  let odd = match.odds.first(where: { $0.id == oddId }) else { return nil }
            return ArenaBetSelection(
                matchId: matchId,
                home: match.home,
                away: match.away,
                oddLabel: odd.label,
                oddValue: odd.value
            )
        }
    }
    private var canSend: Bool {
        activeLeague != nil && selectedOpponent != nil && assignedMatches.count == 3 && selectedArenaSelections.count == assignedMatches.count && selectedStake > 0
    }
    /// Expected total received if the challenger's current pick wins.
    private var expectedPayout: Int {
        let product = selectedArenaSelections.reduce(1.0) { $0 * $1.oddValue }
        return selectedArenaSelections.count == assignedMatches.count ? max(1, Int((Double(selectedStake) * product).rounded())) : 0
    }
    /// Net profit on top of the stake.
    private var expectedNetProfit: Int { expectedPayout - selectedStake }
    private var sportKeys: [String] {
        let keys = activeLeague?.settings.allowedCompetitions.flatMap(\.sportKeys) ?? []
        return Array(Set(keys))
    }

    private func avatarImageData(for userId: String) -> Data? {
        let avatars = ProfileAvatarStore.load(from: profileAvatarStoreData)
        if let data = avatars[userId], !data.isEmpty { return data }
        if userId == leagueService.currentUserId, !legacyAvatarImageData.isEmpty { return legacyAvatarImageData }
        return nil
    }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.fg).dsBackButton()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Volver")
                    Spacer()
                    Text(appLang == .es ? "NUEVO RETO · 1V1" : "NEW CHALLENGE · 1V1")
                        .font(.jbMono(11, weight: .semibold))
                        .tracking(1.5).foregroundStyle(DS.arena)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(appLang == .es ? "CONFIGURAR DUELO" : "SET UP DUEL")
                        .font(.jbMono(10, weight: .semibold))
                        .tracking(2).foregroundStyle(DS.arena)
                    Text(appLang == .es ? "Lanza el\nguante." : "Throw down\nthe challenge.")
                        .font(.bebas(38)).tracking(-1).foregroundStyle(DS.fg)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Step 1: Opponent
                        step1Card
                        // Step 2: Stake
                        step2Card
                        // Step 3: Event
                        step3Card
                        // Pot summary
                        potSummary
                    }
                    .padding(.horizontal, 20).padding(.bottom, 100)
                }
            }
            // Bottom CTA
            VStack {
                Spacer()
                VStack(spacing: 0) {
                    DSButton(title: selectedOpponent.map { appLang == .es ? "Enviar reto a \($0.name) →" : "Send challenge to \($0.name) →" } ?? (appLang == .es ? "Elige rival" : "Choose rival"), style: .arena, fullWidth: true) {
                        sendChallenge()
                    }
                    .disabled(!canSend)
                    .opacity(canSend ? 1 : 0.45)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(DS.bg1)
                .overlay(Rectangle().fill(DS.line).frame(height: 1), alignment: .top)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadSetupData)
        .onChange(of: apiManager.matches.map(\.id)) { _, _ in
            syncDefaultArenaSelections()
        }
        .alert(appLang == .es ? "¡Reto enviado!" : "Challenge sent!", isPresented: $showSent) {
            Button("OK") { dismiss() }
        } message: {
            Text(appLang == .es
                 ? "\(selectedOpponent?.name ?? "Tu rival") verá el reto al cambiar a su perfil."
                 : "\(selectedOpponent?.name ?? "Your rival") will see the challenge when they switch to their profile.")
        }
        .sheet(isPresented: $showStakeEditor) {
            ArenaStakeEditorSheet(stake: $selectedStake, balance: myBalance, lang: appLang)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func loadSetupData() {
        if let league = activeLeague {
            leagueService.loadMembers(for: league)
        }
        guard isDevModeActive else {
            apiManager.matches = []
            return
        }
        guard !sportKeys.isEmpty else {
            apiManager.matches = []
            return
        }
        apiManager.fetchRealOddsMulti(keys: sportKeys, force: false)
    }

    private func syncDefaultArenaSelections() {
        var updated = selectedOddsByMatchId
        for match in assignedMatches {
            let matchId = match.eventId ?? match.id.uuidString
            if updated[matchId] == nil {
                updated[matchId] = match.odds.first?.id
            }
        }
        updated = updated.filter { key, _ in
            assignedMatches.contains { ($0.eventId ?? $0.id.uuidString) == key }
        }
        selectedOddsByMatchId = updated
    }

    private func sendChallenge() {
        guard let league = activeLeague,
              let opponent = selectedOpponent,
              canSend else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let arenaMatches = assignedMatches.map { match in
            ArenaMatch(
                id: match.eventId ?? match.id.uuidString,
                home: match.home,
                away: match.away,
                league: match.league,
                startDate: match.startDate,
                odds: Array(match.odds.prefix(3))
            )
        }
        leagueService.createArenaDuel(
            leagueId: league.id,
            opponentId: opponent.id,
            opponentName: opponent.name,
            wager: selectedStake,
            matches: arenaMatches,
            challengerSelections: selectedArenaSelections
        )
        showSent = true
    }

    private var step1Card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(appLang == .es ? "1 · OPONENTE" : "1 · OPPONENT")
                    .font(.jbMono(10, weight: .semibold))
                    .tracking(1.5).foregroundStyle(DS.fg3)
                Spacer()
                DSPill(text: appLang == .es ? "SELECCIONADO" : "SELECTED",
                       bg: DS.arena.opacity(0.14), border: DS.arena.opacity(0.4), fg: DS.arena, fontSize: 9)
            }
            if leagueMembers.isEmpty {
                Text(appLang == .es
                     ? "Aún no hay rivales en esta liga. Cambia al panel DEV, entra como tester y únete con el código de la liga."
                     : "There are no rivals in this league yet. Switch to the DEV panel, enter as a tester and join with the league code.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.warn)
            } else {
                VStack(spacing: 8) {
                    ForEach(leagueMembers) { member in
                        let selected = member.id == selectedOpponent?.id
                        Button { selectedOpponentId = member.id } label: {
                            HStack(spacing: 12) {
                                DSAvatar(name: member.name, size: 42, accent: selected, imageData: avatarImageData(for: member.id))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.name).font(.system(size: 15, weight: .bold)).foregroundStyle(DS.fg)
                                    Text("\(member.points) pts")
                                        .font(.system(size: 12)).foregroundStyle(DS.fg3)
                                }
                                Spacer()
                                if selected {
                                    DSPill(text: appLang == .es ? "RIVAL" : "RIVAL", bg: DS.arena.opacity(0.14), border: DS.arena.opacity(0.4), fg: DS.arena, fontSize: 9)
                                }
                            }
                            .padding(10)
                            .background(selected ? DS.arena.opacity(0.08) : DS.bg2)
                            .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16).dsCard()
    }

    private var step2Card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(appLang == .es ? "2 · APUESTA" : "2 · STAKE")
                    .font(.jbMono(10, weight: .semibold))
                    .tracking(1.5).foregroundStyle(DS.fg3)
                Spacer()
                Text(appLang == .es ? "SALDO \(myBalance)" : "BALANCE \(myBalance)")
                    .font(.jbMono(11, weight: .semibold)).foregroundStyle(DS.fg3)
            }
            HStack(spacing: 6) {
                ForEach([10, 25, 50, 100], id: \.self) { v in
                    Button { selectedStake = v } label: {
                        Text("\(v)")
                            .font(.bebas(20))
                            .foregroundStyle(selectedStake == v ? .white : DS.fg)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(selectedStake == v ? DS.arena : DS.bg2)
                            .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                                .stroke(selectedStake == v ? DS.arena : DS.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                // Custom amount
                Button { showStakeEditor = true } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(![10, 25, 50, 100].contains(selectedStake) ? .white : DS.fg)
                        .frame(width: 48, height: 48)
                        .background(![10, 25, 50, 100].contains(selectedStake) ? DS.arena : DS.bg2)
                        .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                            .stroke(![10, 25, 50, 100].contains(selectedStake) ? DS.arena : DS.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appLang == .es ? "Editar apuesta" : "Edit bet")
            }
            // Show current custom amount when not a preset
            if ![10, 25, 50, 100].contains(selectedStake) {
                Text(appLang == .es ? "Apuesta personalizada: \(selectedStake) pts" : "Custom stake: \(selectedStake) pts")
                    .font(.jbMono(10, weight: .semibold))
                    .foregroundStyle(DS.arena)
            }
            Text(appLang == .es ? "⚠ Los retos ignoran tu límite de apuestas diarias." : "⚠ Challenges ignore your daily bet limit.")
                .font(.system(size: 11)).foregroundStyle(DS.fg3)
        }
        .padding(16).dsCard()
    }

    private var step3Card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(appLang == .es ? "3 · TRES PICKS OBLIGATORIOS" : "3 · THREE REQUIRED PICKS")
                    .font(.jbMono(10, weight: .semibold))
                    .tracking(1.5).foregroundStyle(DS.fg3)
                Spacer()
                DSPill(text: "\(selectedArenaSelections.count)/3",
                       bg: DS.arena.opacity(0.14), border: DS.arena.opacity(0.4), fg: DS.arena, fontSize: 9)
            }
            if assignedMatches.count < 3 {
                Text(appLang == .es ? "No hay 3 partidos válidos para crear un reto ahora mismo." : "There are not 3 valid matches available for a challenge right now.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.warn)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(assignedMatches.enumerated()), id: \.element.id) { index, match in
                        let matchId = match.eventId ?? match.id.uuidString
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                DSCrest(team: arenaTeamCode(match.home), size: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(index + 1). \(match.home) vs \(match.away)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(DS.fg)
                                        .lineLimit(1)
                                    Text("\(match.league) · \(arenaTime(match.startDate))")
                                        .textCase(.uppercase)
                                        .font(.system(size: 11))
                                        .foregroundStyle(DS.fg3)
                                }
                                Spacer()
                                if selectedOddsByMatchId[matchId] != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DS.arena)
                                        .accessibilityHidden(true)
                                }
                            }
                            HStack(spacing: 6) {
                                ForEach(match.odds.prefix(3).map { $0 }) { odd in
                                    let selected = selectedOddsByMatchId[matchId] == odd.id
                                    Button { selectedOddsByMatchId[matchId] = odd.id } label: {
                                        VStack(spacing: 2) {
                                            Text(readableOddLabel(odd.label, home: match.home, away: match.away, lang: appLang))
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(selected ? DS.accentInk : DS.fg3)
                                                .lineLimit(1)
                                            Text(String(format: "%.2f", odd.value))
                                                .font(.bebas(18))
                                                .foregroundStyle(selected ? DS.accentInk : DS.fg)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background(selected ? DS.arena : DS.bg2)
                                        .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(10)
                        .background(DS.bg2)
                        .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                    }
                }
            }
        }
        .padding(16).dsCard()
    }

    private var potSummary: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appLang == .es ? "TU APUESTA" : "YOUR STAKE")
                    .font(.jbMono(10, weight: .semibold))
                    .tracking(1.5).foregroundStyle(DS.arena)
                Text("\(selectedStake)")
                    .font(.bebas(56)).tracking(-2).foregroundStyle(DS.arena)
                Text(appLang == .es ? "PUNTOS EN JUEGO" : "POINTS AT RISK")
                    .font(.jbMono(11, weight: .semibold))
                    .tracking(1.5).foregroundStyle(DS.fg3)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(appLang == .es ? "SI GANAS EL RETO" : "IF YOU WIN").font(.jbMono(11, weight: .semibold))
                    .tracking(1.5).foregroundStyle(DS.fg3)
                    .multilineTextAlignment(.trailing)
                Text("+\(expectedNetProfit)").font(.bebas(28)).foregroundStyle(DS.win)
                Text(appLang == .es ? "NETO · COBRAS \(expectedPayout)" : "NET · YOU RECEIVE \(expectedPayout)").font(.jbMono(10, weight: .semibold))
                    .tracking(1.2).foregroundStyle(DS.win.opacity(0.8))
                Text(appLang == .es ? "cuota total \(String(format: "%.2f", selectedArenaSelections.reduce(1.0) { $0 * $1.oddValue }))" : "total odds \(String(format: "%.2f", selectedArenaSelections.reduce(1.0) { $0 * $1.oddValue }))")
                    .font(.jbMono(9, weight: .semibold))
                    .tracking(1.2).foregroundStyle(DS.fg3)
            }
        }
        .padding(18)
        .background(DS.arena.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
            .stroke(DS.arena.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Arena Incoming Full Takeover (ScreenArenaIncoming)
struct ArenaIncomingScreen: View {
    let duel: ArenaDuel
    let leagueService: LeagueService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @State private var isChoosingPick = false
    @AppStorage("profileAvatarImageData") private var legacyAvatarImageData: Data = Data()
    @AppStorage("betsyProfileAvatarStoreDataV1") private var profileAvatarStoreData: Data = Data()

    private var challengerPick: ArenaBetSelection? { duel.challengerSelections.first }
    private var match: ArenaMatch? { duel.matches.first }
    private var challengerCombinedOdds: Double {
        duel.challengerSelections.reduce(1.0) { $0 * $1.oddValue }
    }
    private var challengerPickText: String {
        guard let pick = challengerPick else { return appLang == .es ? "Pick pendiente" : "Pick pending" }
        let first = readableOddLabel(pick.oddLabel, home: pick.home, away: pick.away, lang: appLang)
        let extra = max(duel.challengerSelections.count - 1, 0)
        return extra > 0 ? "\(first) +\(extra)" : first
    }
    private func avatarImageData(for userId: String) -> Data? {
        let avatars = ProfileAvatarStore.load(from: profileAvatarStoreData)
        if let data = avatars[userId], !data.isEmpty { return data }
        if userId == leagueService.currentUserId, !legacyAvatarImageData.isEmpty { return legacyAvatarImageData }
        return nil
    }
    /// Time remaining until the match kicks off (or 4h fallback for anytime duels).
    private var remainingTimeText: String {
        let deadline: Date = {
            if let kickoff = match?.startDate, kickoff > Date() {
                return kickoff
            }
            // Default 4h response window from createdAt
            return (duel.createdAt ?? Date()).addingTimeInterval(4 * 60 * 60)
        }()
        let interval = max(deadline.timeIntervalSinceNow, 0)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours <= 0 && minutes <= 0 { return appLang == .es ? "expira ya" : "expires now" }
        if hours <= 0 { return "\(minutes)m" }
        return "\(hours)h \(minutes)m"
    }
    var body: some View {
        ZStack {
            Color(dsHex: "0a0a0b").ignoresSafeArea()
            // Red radial glow
            Circle().fill(DS.arena.opacity(0.5)).frame(width: 400).blur(radius: 80)
                .offset(y: -200)
            DSArenaGrid(opacity: 0.5)
            // Bottom fade
            LinearGradient(colors: [.clear, Color(dsHex: "0a0a0b")],
                           startPoint: .top, endPoint: .bottom)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white).dsBackButton()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Volver")
                    Spacer()
                    DSPill(text: appLang == .es ? "RETO ENTRANTE" : "INCOMING CHALLENGE",
                           bg: DS.arena.opacity(0.2), border: DS.arena.opacity(0.5),
                           fg: DS.arena, dot: DS.arena)
                    Spacer()
                    Color.clear.frame(width: 36)
                }
                .padding(.horizontal, 20).padding(.top, 8)

                Spacer()

                VStack(spacing: 12) {
                    Text(appLang == .es ? "· DUELO ·" : "· DUEL ·")
                        .font(.jbMono(11, weight: .semibold))
                        .tracking(4).foregroundStyle(DS.arena)
                    DSAvatar(name: duel.challengerName, size: 88, imageData: avatarImageData(for: duel.challengerId))
                    Text(appLang == .es ? "\(duel.challengerName)\nte reta." : "\(duel.challengerName)\nchallenges you.")
                        .font(.bebas(56)).tracking(-2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(-6)
                    Text(appLang == .es ? "Ha lanzado un duelo directo en \(match?.league ?? "tu liga"). Tienes " : "They launched a direct duel in \(match?.league ?? "your league"). You have ")
                        .font(.system(size: 14)).foregroundStyle(DS.fg2)
                        + Text(remainingTimeText).font(.system(size: 14, weight: .bold)).foregroundStyle(DS.arena)
                        + Text(appLang == .es ? " para responder." : " to respond.").font(.system(size: 14)).foregroundStyle(DS.fg2)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                Spacer()

                // Matchup card
                VStack(spacing: 14) {
                    HStack {
                        Text(appLang == .es ? "APUESTA" : "STAKE")
                            .font(.jbMono(10, weight: .semibold))
                            .tracking(1.5).foregroundStyle(DS.arena)
                        Spacer()
                        Text("\(duel.wager) pts")
                            .font(.bebas(28)).tracking(-1).foregroundStyle(DS.arena)
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(appLang == .es ? "\(duel.challengerName) Eligió" : "\(duel.challengerName) Picked").textCase(.uppercase)
                                .font(.jbMono(11, weight: .semibold))
                                .tracking(1.5).foregroundStyle(DS.fg3)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    DSCrest(team: arenaTeamCode(challengerPick?.home ?? match?.home ?? "BET"), size: 32)
                                    Text(challengerPickText).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                        .lineLimit(1)
                                }
                                Text(appLang == .es ? "3 picks · cuota total \(String(format: "%.2f", challengerCombinedOdds))" : "3 picks · total odds \(String(format: "%.2f", challengerCombinedOdds))")
                                    .font(.jbMono(10, weight: .semibold))
                                    .foregroundStyle(DS.fg3)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Rectangle().fill(DS.line).frame(width: 1)
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(appLang == .es ? "TU RESPUESTA" : "YOUR ANSWER")
                                .font(.jbMono(11, weight: .semibold))
                                .tracking(1.5).foregroundStyle(DS.accent)
                            HStack(spacing: 8) {
                                Text(appLang == .es ? "Elige tus 3 picks" : "Choose your 3 picks").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                    .lineLimit(1)
                                DSAvatar(name: duel.opponentName, size: 32, imageData: avatarImageData(for: duel.opponentId))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(18)
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 20)

                VStack(spacing: 10) {
                    DSButton(title: appLang == .es ? "⚔ Aceptar reto" : "⚔ Accept challenge", style: .arena, fullWidth: true, height: 56) {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        isChoosingPick = true
                    }
                    DSButton(title: appLang == .es ? "Rechazar" : "Decline", style: .ghost, fullWidth: true) {
                        leagueService.declineArena(duelId: duel.id, leagueId: duel.leagueId)
                        leagueService.pendingArenaInvite = nil
                        dismiss()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $isChoosingPick) {
            ArenaDuelPickScreen(
                duel: duel,
                leagueService: leagueService,
                requiresPickBeforeDismiss: true,
                acceptOnConfirm: true,
                onCompleted: {
                    isChoosingPick = false
                    leagueService.pendingArenaInvite = nil
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Arena Duel Pick Screen

private struct ArenaDuelPickScreen: View {
    let duel: ArenaDuel
    @ObservedObject var leagueService: LeagueService
    let requiresPickBeforeDismiss: Bool
    let acceptOnConfirm: Bool
    let onCompleted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @AppStorage("profileAvatarImageData") private var legacyAvatarImageData: Data = Data()
    @AppStorage("betsyProfileAvatarStoreDataV1") private var profileAvatarStoreData: Data = Data()
    @State private var selectedOddsByMatchId: [String: String] = [:]

    init(
        duel: ArenaDuel,
        leagueService: LeagueService,
        requiresPickBeforeDismiss: Bool = false,
        acceptOnConfirm: Bool = false,
        onCompleted: @escaping () -> Void = {}
    ) {
        self.duel = duel
        self.leagueService = leagueService
        self.requiresPickBeforeDismiss = requiresPickBeforeDismiss
        self.acceptOnConfirm = acceptOnConfirm
        self.onCompleted = onCompleted
    }

    private var liveDuel: ArenaDuel {
        if let active = leagueService.activeArena, active.id == duel.id {
            return active
        }
        return duel
    }

    private var currentUserId: String {
        leagueService.currentUserId ?? ""
    }

    private var isChallenger: Bool {
        currentUserId == liveDuel.challengerId
    }

    private var currentUserName: String {
        isChallenger ? liveDuel.challengerName : liveDuel.opponentName
    }

    private var rivalName: String {
        isChallenger ? liveDuel.opponentName : liveDuel.challengerName
    }

    private var currentSelections: [ArenaBetSelection] {
        isChallenger ? liveDuel.challengerSelections : liveDuel.opponentSelections
    }

    private var rivalSelections: [ArenaBetSelection] {
        isChallenger ? liveDuel.opponentSelections : liveDuel.challengerSelections
    }
    private var myPotentialPayout: Int {
        max(Int((Double(liveDuel.wager) * currentSelections.reduce(1.0) { $0 * $1.oddValue }).rounded()) - liveDuel.wager, 0)
    }
    private var rivalPotentialPayout: Int {
        max(Int((Double(liveDuel.wager) * rivalSelections.reduce(1.0) { $0 * $1.oddValue }).rounded()) - liveDuel.wager, 0)
    }
    private var selectedPotentialPayout: Int {
        let product = pendingSelections.reduce(1.0) { $0 * $1.oddValue }
        return pendingSelections.count == liveDuel.matches.count ? max(Int((Double(liveDuel.wager) * product).rounded()) - liveDuel.wager, 0) : 0
    }

    private var pendingSelections: [ArenaBetSelection] {
        liveDuel.matches.compactMap { match in
            guard let oddId = selectedOddsByMatchId[match.id],
                  let odd = match.odds.first(where: { $0.id == oddId }) else { return nil }
            return ArenaBetSelection(
                matchId: match.id,
                home: match.home,
                away: match.away,
                oddLabel: odd.label,
                oddValue: odd.value
            )
        }
    }

    private var canConfirm: Bool {
        !liveDuel.matches.isEmpty && pendingSelections.count == liveDuel.matches.count && currentSelections.isEmpty
    }
    private var selectedCombinedOdds: Double {
        pendingSelections.reduce(1.0) { $0 * $1.oddValue }
    }

    private func avatarImageData(for userId: String) -> Data? {
        let avatars = ProfileAvatarStore.load(from: profileAvatarStoreData)
        if let data = avatars[userId], !data.isEmpty { return data }
        if userId == leagueService.currentUserId, !legacyAvatarImageData.isEmpty { return legacyAvatarImageData }
        return nil
    }

    private var stateLabel: String {
        if currentSelections.isEmpty {
            return requiresPickBeforeDismiss ? "ACEPTADO · ELIGE TU PICK" : "EN JUEGO · FALTA TU PICK"
        }
        if rivalSelections.isEmpty {
            return "PICK CONFIRMADO · ESPERANDO RIVAL"
        }
        return "PICKS CONFIRMADOS · ESPERANDO RESULTADO"
    }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            Circle()
                .fill(DS.arena.opacity(0.24))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(y: -260)
            DSArenaGrid(opacity: 0.24)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        hero
                        if liveDuel.matches.isEmpty {
                            unavailableState
                        } else if currentSelections.isEmpty {
                            matchPicker
                            oddsPicker
                            contextCard
                        } else {
                            lockedSelectionCard
                            contextCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 110)
                }
            }

            if currentSelections.isEmpty {
                VStack {
                    Spacer()
                    DSButton(title: appLang == .es ? "Confirmar pick de Arena →" : "Confirm Arena pick →", style: .arena, fullWidth: true, height: 56) {
                        confirmPick()
                    }
                    .disabled(!canConfirm)
                    .opacity(canConfirm ? 1 : 0.45)
                .accessibilityHint(canConfirm
                                       ? (appLang == .es ? "Confirma tu selección de Arena" : "Confirm your Arena pick")
                                       : (appLang == .es ? "Elige un pick en los tres partidos para confirmar" : "Choose one pick in all three matches to confirm"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(DS.bg1)
                    .overlay(Rectangle().fill(DS.line).frame(height: 1), alignment: .top)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            syncDefaultPickSelections()
        }
        .interactiveDismissDisabled(requiresPickBeforeDismiss && currentSelections.isEmpty)
    }

    private var header: some View {
        HStack {
            if requiresPickBeforeDismiss && currentSelections.isEmpty {
                Color.clear.frame(width: 36, height: 36)
            } else {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.fg)
                        .dsBackButton()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Volver")
            }
            Spacer()
            Text(appLang == .es ? "ARENA · PICK" : "ARENA · PICK")
                .font(.jbMono(11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(DS.arena)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var hero: some View {
        VStack(spacing: 16) {
            DSPill(text: stateLabel,
                   bg: DS.arena.opacity(0.14), border: DS.arena.opacity(0.42), fg: DS.arena, fontSize: 10, dot: DS.arena)

            HStack(spacing: 14) {
                DSAvatar(name: liveDuel.challengerName, size: 62, accent: isChallenger, imageData: avatarImageData(for: liveDuel.challengerId))
                VStack(spacing: 2) {
                    Text(appLang == .es ? "VS" : "VS")
                        .font(.bebas(42))
                        .foregroundStyle(DS.arena)
                    Text("\(liveDuel.wager) PTS")
                        .font(.jbMono(10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(DS.fg3)
                }
                DSAvatar(name: liveDuel.opponentName, size: 62, accent: !isChallenger, imageData: avatarImageData(for: liveDuel.opponentId))
            }

            VStack(spacing: 4) {
                    Text(currentSelections.isEmpty
                     ? (appLang == .es ? "Elige tus 3 picks contra \(rivalName)" : "Choose your 3 picks against \(rivalName)")
                     : (appLang == .es ? "Pick bloqueado" : "Pick locked"))
                    .font(.bebas(32))
                    .tracking(-0.6)
                    .foregroundStyle(DS.fg)
                    .multilineTextAlignment(.center)
                Text(currentSelections.isEmpty
                     ? (appLang == .es
                        ? "Gana quien acierta más. Si empatáis, decide la cuota total."
                        : "Most correct picks wins. If tied, total odds decide.")
                     : (appLang == .es
                        ? "Tu pick ya está cerrado. Ahora el cobro depende de tu cuota y del acierto."
                        : "Your pick is locked. Your payout now depends on your odds and result."))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.fg3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(DS.arena.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous).stroke(DS.arena.opacity(0.28), lineWidth: 1))
    }

    private var unavailableState: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DS.warn)
            Text(appLang == .es ? "No hay partido asignado" : "No assigned match")
                .font(.bebas(26))
                .foregroundStyle(DS.fg)
            Text(appLang == .es ? "Este reto no tiene evento válido. Cancela y crea uno nuevo con partidos disponibles." : "This challenge has no valid event. Cancel and create a new one with available matches.")
                .font(.system(size: 12))
                .foregroundStyle(DS.fg3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .dsCard()
    }

    private var matchPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appLang == .es ? "3 PARTIDOS ASIGNADOS" : "3 ASSIGNED MATCHES")
                .font(.jbMono(10, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(DS.fg3)
            ForEach(liveDuel.matches) { match in
                HStack(spacing: 12) {
                    DSCrest(team: arenaTeamCode(match.home), size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(match.home) vs \(match.away)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DS.fg)
                            .lineLimit(1)
                        Text("\(match.league) · \(arenaTime(match.startDate))")
                            .textCase(.uppercase)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.fg3)
                    }
                    Spacer()
                    Image(systemName: selectedOddsByMatchId[match.id] == nil ? "circle" : "checkmark.circle.fill")
                        .foregroundStyle(selectedOddsByMatchId[match.id] == nil ? DS.fg3 : DS.arena)
                }
                .padding(12)
                .background(DS.bg2)
                .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous).stroke(DS.line, lineWidth: 1))
                .accessibilityLabel(appLang == .es ? "Partido \(match.home) contra \(match.away), \(match.league)" : "Match \(match.home) against \(match.away), \(match.league)")
                .accessibilityValue(selectedOddsByMatchId[match.id] == nil ? (appLang == .es ? "Sin pick" : "No pick") : (appLang == .es ? "Pick elegido" : "Pick selected"))
            }
        }
        .padding(16)
        .dsCard()
    }

    private var oddsPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appLang == .es ? "ELIGE UN PICK EN CADA PARTIDO" : "CHOOSE ONE PICK PER MATCH")
                .font(.jbMono(10, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(DS.fg3)
            ForEach(liveDuel.matches) { match in
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(match.home) vs \(match.away)")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(DS.fg)
                    ForEach(match.odds.prefix(3).map { $0 }) { odd in
                        let selected = selectedOddsByMatchId[match.id] == odd.id
                        Button { selectedOddsByMatchId[match.id] = odd.id } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(readableOddLabel(odd.label, home: match.home, away: match.away, lang: appLang))
                                        .font(.system(size: 15, weight: .black))
                                        .foregroundStyle(selected ? DS.accentInk : DS.fg)
                                        .lineLimit(1)
                                    Text(appLang == .es ? "Cuota \(String(format: "%.2f", odd.value))" : "Odds \(String(format: "%.2f", odd.value))")
                                        .font(.jbMono(11, weight: .semibold))
                                        .foregroundStyle(selected ? DS.accentInk.opacity(0.75) : DS.fg3)
                                }
                                Spacer()
                                Text(String(format: "%.2f", odd.value))
                                    .font(.bebas(28))
                                    .foregroundStyle(selected ? DS.accentInk : DS.arena)
                            }
                            .padding(12)
                            .background(selected ? DS.arena : DS.bg2)
                            .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous).stroke(selected ? DS.arena : DS.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(appLang == .es
                                            ? "\(readableOddLabel(odd.label, home: match.home, away: match.away, lang: appLang)), cuota \(String(format: "%.2f", odd.value))"
                                            : "\(readableOddLabel(odd.label, home: match.home, away: match.away, lang: appLang)), odds \(String(format: "%.2f", odd.value))")
                        .accessibilityValue(selected ? (appLang == .es ? "Seleccionado" : "Selected") : (appLang == .es ? "No seleccionado" : "Not selected"))
                        .accessibilityHint(selected ? (appLang == .es ? "Seleccionado" : "Selected") : (appLang == .es ? "Doble toque para seleccionar" : "Double tap to select"))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .dsCard()
    }

    private var lockedSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appLang == .es ? "TU PICK" : "YOUR PICK")
                .font(.jbMono(10, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(DS.fg3)
            ForEach(currentSelections) { selection in
                ArenaSelectionSummary(selection: selection, title: currentUserName, tint: DS.arena)
            }
            Text(rivalSelections.isEmpty
                 ? (appLang == .es ? "Ya está enviado. Falta el pick de \(rivalName)." : "Sent. \(rivalName)'s pick is still missing.")
                 : (appLang == .es ? "Ambos picks están confirmados. El duelo queda esperando resultado simulado." : "Both picks are confirmed. The duel is waiting for the simulated result."))
                .font(.system(size: 12))
                .foregroundStyle(DS.fg3)
                .lineSpacing(3)
            Text(appLang == .es
                 ? "Si tu pick acierta, ganarías +\(myPotentialPayout) pts netos."
                 : "If your pick wins, you would earn +\(myPotentialPayout) net pts.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.win)
        }
        .padding(16)
        .dsCard()
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(appLang == .es ? "RESUMEN DEL DUELO" : "DUEL SUMMARY")
                    .font(.jbMono(10, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(DS.fg3)
                Spacer()
                Text(appLang == .es ? "stake \(liveDuel.wager)" : "stake \(liveDuel.wager)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.fg)
            }

            if rivalSelections.isEmpty {
                if currentSelections.isEmpty, pendingSelections.count == liveDuel.matches.count {
                    Text(appLang == .es
                         ? "Si ganas el reto, ganarías +\(selectedPotentialPayout) pts netos."
                         : "If you win the challenge, you would earn +\(selectedPotentialPayout) net pts.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.win)
                    Text(appLang == .es
                         ? "Tu cuota total es \(String(format: "%.2f", selectedCombinedOdds))."
                         : "Your total odds are \(String(format: "%.2f", selectedCombinedOdds)).")
                        .font(.jbMono(11, weight: .semibold))
                        .foregroundStyle(DS.fg3)
                } else if currentSelections.isEmpty {
                    Text(appLang == .es ? "Elige un pick en los 3 partidos para ver tu ganancia posible." : "Choose one pick in all 3 matches to see your possible profit.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.warn)
                } else {
                    Text(appLang == .es ? "\(rivalName) todavía no ha enviado su pick." : "\(rivalName) has not sent a pick yet.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.warn)
                }
            } else {
                ForEach(rivalSelections) { selection in
                    ArenaSelectionSummary(selection: selection, title: rivalName, tint: DS.fg2)
                }
                Text(appLang == .es
                     ? "\(rivalName) ganaría +\(rivalPotentialPayout) pts netos si acierta."
                     : "\(rivalName) would earn +\(rivalPotentialPayout) net pts if they win.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.fg3)
            }
        }
        .padding(16)
        .dsCard()
    }

    private func confirmPick() {
        guard canConfirm else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        if acceptOnConfirm {
            leagueService.submitArenaSelection(duel: liveDuel, selections: pendingSelections)
            leagueService.acceptArena(duelId: liveDuel.id, leagueId: liveDuel.leagueId) { success in
                guard success else { return }
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    onCompleted()
                }
            }
        } else {
            leagueService.submitArenaSelection(duel: liveDuel, selections: pendingSelections)
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                onCompleted()
            }
        }
    }

    private func syncDefaultPickSelections() {
        var updated = selectedOddsByMatchId
        for match in liveDuel.matches {
            if updated[match.id] == nil {
                updated[match.id] = match.odds.first?.id
            }
        }
        updated = updated.filter { matchId, oddId in
            liveDuel.matches.contains { match in
                match.id == matchId && match.odds.contains { $0.id == oddId }
            }
        }
        selectedOddsByMatchId = updated
    }
}

private struct ArenaSelectionSummary: View {
    let selection: ArenaBetSelection
    let title: String
    let tint: Color
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    var body: some View {
        HStack(spacing: 10) {
            DSCrest(team: arenaTeamCode(selection.home), size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.jbMono(10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(DS.fg3)
                Text(readableOddLabel(selection.oddLabel, home: selection.home, away: selection.away, lang: appLang))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(DS.fg)
                    .lineLimit(1)
                Text("\(selection.home) vs \(selection.away)")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.fg3)
                    .lineLimit(1)
            }
            Spacer()
            Text(String(format: "%.2f", selection.oddValue))
                .font(.bebas(24))
                .foregroundStyle(tint)
        }
        .padding(12)
        .background(DS.bg2)
        .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous).stroke(tint.opacity(0.24), lineWidth: 1))
    }
}

// MARK: - Arena Stake Editor Sheet

private struct ArenaStakeEditorSheet: View {
    @Binding var stake: Int
    let balance: Int
    let lang: AppLang
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    private var parsedValue: Int { Int(draft) ?? 0 }
    private var canApply: Bool { parsedValue > 0 && parsedValue <= max(balance, 0) }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lang == .es ? "APUESTA ARENA" : "ARENA STAKE")
                            .font(.jbMono(10, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(DS.arena)
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
                    .accessibilityLabel(appLang == .es ? "Cerrar" : "Close")
                }

                VStack(spacing: 6) {
                    Text(draft.isEmpty ? "0" : draft)
                        .font(.bebas(56))
                        .foregroundStyle(canApply || draft.isEmpty ? DS.arena : DS.loss)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(DS.bg1)
                        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                            .stroke(canApply || draft.isEmpty ? DS.arena.opacity(0.4) : DS.loss.opacity(0.55), lineWidth: 1))
                    Text(lang == .es ? "Saldo disponible: \(balance) pts" : "Available balance: \(balance) pts")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(canApply || draft.isEmpty ? DS.fg3 : DS.loss)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(1...9, id: \.self) { n in
                        keypadButton("\(n)") { appendDigit(n) }
                    }
                    keypadButton("⌫") { deleteDigit() }
                    keypadButton("0") { appendDigit(0) }
                    keypadButton(lang == .es ? "OK" : "OK", isPrimary: true) { apply() }
                        .disabled(!canApply)
                        .opacity(canApply ? 1 : 0.45)
                }
            }
            .padding(20)
        }
        .onAppear { draft = stake > 0 ? "\(stake)" : "" }
    }

    private func keypadButton(_ title: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(isPrimary ? .white : DS.fg)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(isPrimary ? DS.arena : DS.bg2)
                .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                    .stroke(isPrimary ? DS.arena : DS.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func appendDigit(_ digit: Int) {
        guard draft.count < 6 else { return }
        if draft == "0" { draft = "" }
        draft.append("\(digit)")
    }
    private func deleteDigit() { if !draft.isEmpty { draft.removeLast() } }
    private func apply() { guard canApply else { return }; stake = parsedValue; dismiss() }
}

private func arenaTeamCode(_ name: String) -> String {
    let words = name
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
    if words.count >= 2 {
        return words.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
    return String(name.prefix(3)).uppercased()
}

private func arenaTime(_ date: Date?) -> String {
    guard let date else { return "HOY" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateFormat = Calendar.current.isDateInToday(date) ? "'HOY' HH:mm" : "EEE HH:mm"
    return formatter.string(from: date)
}
