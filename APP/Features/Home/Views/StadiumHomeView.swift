import SwiftUI

// MARK: - Home Screen (3 states: empty / dashboard / challenge)
struct BetsyHomeScreen: View {
    @EnvironmentObject var leagueService: LeagueService
    @AppStorage("displayName") private var displayName: String = ""
    @AppStorage("selectedLeagueId") private var selectedLeagueId = ""
    @AppStorage("betsyTicketHistoryDataV2") private var ticketHistoryData: Data = Data()
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @Binding var selectedTab: BetsyTab

    private var hasLeague: Bool { !leagueService.myLeagues.isEmpty }
    private var activeLeague: FriendLeague? {
        ActiveLeagueStore.resolve(from: leagueService.myLeagues, selectedId: selectedLeagueId)
    }

    private var userName: String {
        if leagueService.currentDevProfile != .real {
            return leagueService.currentDevProfile.displayName
        }
        let n = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        return n.isEmpty ? (appLang == .es ? "Jugador" : "Player") : n
    }

    private var myMember: LeagueMember? {
        guard let league = activeLeague,
              let uid = leagueService.currentUserId else { return nil }
        return leagueService.membersByLeague[league.id]?.first(where: { $0.id == uid })
    }

    private var myBalance: Int { myMember?.points ?? 0 }
    private var myDeltaToday: Int { myMember?.pointsToday ?? 0 }

    private var myRank: Int? {
        guard let league = activeLeague,
              let uid = leagueService.currentUserId else { return nil }
        let sorted = (leagueService.membersByLeague[league.id] ?? [])
            .sorted { $0.points > $1.points }
        return sorted.firstIndex(where: { $0.id == uid }).map { $0 + 1 }
    }

    private var totalMembers: Int { activeLeague?.members ?? 0 }
    private var tickets: [UserTicket] {
        guard let leagueId = activeLeague?.id else { return [] }
        let uid = leagueService.currentUserId ?? "anonymous"
        return TicketStore.loadHistory(from: ticketHistoryData)["\(uid)|\(leagueId)"] ?? []
    }
    private var hitRate: Int {
        let resolved = tickets.filter { $0.isResultKnown && !$0.isWithdrawn }
        guard !resolved.isEmpty else { return 0 }
        let won = resolved.filter(\.wasWon).count
        return Int((Double(won) / Double(resolved.count) * 100).rounded())
    }
    private var remainingBetsToday: Int {
        guard let league = activeLeague else { return 0 }
        let usedToday = tickets.filter { Calendar.current.isDate($0.date, inSameDayAs: DevSimulationClock.now()) && !$0.isWithdrawn }.count
        return max(league.settings.betsPerActiveDay - usedToday, 0)
    }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            if hasLeague, let league = activeLeague {
                HomeDashboardView(
                    league: league,
                    userName: userName,
                    myBalance: myBalance,
                    myDeltaToday: myDeltaToday,
                    myRank: myRank,
                    totalMembers: totalMembers,
                    hitRate: hitRate,
                    remainingBetsToday: remainingBetsToday,
                    selectedTab: $selectedTab
                )
                .environmentObject(leagueService)
                .onAppear { leagueService.loadMembers(for: league) }
            } else {
                HomeEmptyView(userName: userName, selectedTab: $selectedTab)
            }
        }
    }
}

// MARK: - Shared top chrome
private struct HomeTopBar: View {
    var leagueName: String = "Sin liga"
    var userName: String = "Yo"
    @Binding var selectedTab: BetsyTab
    @EnvironmentObject var leagueService: LeagueService
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @State private var showLeagueSwitcher = false

    var body: some View {
        HStack(spacing: 10) {
            BetsyMark(size: 22)
            Button {
                guard !leagueService.myLeagues.isEmpty else {
                    selectedTab = .league
                    return
                }
                UISelectionFeedbackGenerator().selectionChanged()
                showLeagueSwitcher = true
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(appLang == .es ? "SELECCIONADA" : "SELECTED")
                        .font(.jbMono(11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(DS.fg3)
                    HStack(spacing: 4) {
                        Text(leagueName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DS.fg)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.fg3)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appLang == .es ? "Cambiar de liga" : "Change league")
            .accessibilityHint(appLang == .es ? "Liga seleccionada: \(leagueName)" : "Selected league: \(leagueName)")

            Spacer()
        }
        .padding(.horizontal, DS.screenHPad)
        .padding(.bottom, 12)
        .sheet(isPresented: $showLeagueSwitcher) {
            LeagueSwitcherSheet(isPresented: $showLeagueSwitcher)
                .environmentObject(leagueService)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - League switcher sheet
struct LeagueSwitcherSheet: View {
    @EnvironmentObject var leagueService: LeagueService
    @AppStorage("selectedLeagueId") private var selectedLeagueId = ""
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @Binding var isPresented: Bool

    private var leagues: [FriendLeague] { leagueService.myLeagues }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appLang == .es ? "CAMBIAR SELECCIÓN" : "CHANGE SELECTION")
                            .font(.jbMono(10, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(DS.fg3)
                        Text(appLang == .es ? "Tus ligas" : "Your leagues")
                            .font(.bebas(32))
                            .tracking(-0.5)
                            .foregroundStyle(DS.fg)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(leagues) { league in
                            let isActive = league.id == selectedLeagueId
                            Button {
                                UISelectionFeedbackGenerator().selectionChanged()
                                selectedLeagueId = league.id
                                leagueService.loadMembers(for: league)
                                leagueService.listenForArena(leagueId: league.id)
                                isPresented = false
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12).fill(DS.bg3)
                                        Text(String(league.name.prefix(2)).uppercased())
                                            .font(.jbMono(16, weight: .black))
                                            .foregroundStyle(DS.fg)
                                            .accessibilityHidden(true)
                                    }
                                    .frame(width: 44, height: 44)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(league.name)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(DS.fg)
                                            .lineLimit(1)
                                        Text(appLang == .es ? "\(league.members) jugadores · \(league.code)" : "\(league.members) players · \(league.code)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(DS.fg3)
                                    }
                                    Spacer()
                                    if isActive {
                                        DSPill(text: appLang == .es ? "SELECCIONADA" : "SELECTED",
                                               bg: DS.accentSoft, border: DS.accentLine,
                                               fg: DS.accent, fontSize: 9, dot: DS.accent)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(DS.fg3)
                                            .accessibilityHidden(true)
                                    }
                                }
                                .padding(14)
                                .background(isActive ? DS.accentSoft : DS.bg1)
                                .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                                        .stroke(isActive ? DS.accentLine : DS.line, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

// MARK: - State 1: Empty
private struct HomeEmptyView: View {
    var userName: String = "Jugador"
    @Binding var selectedTab: BetsyTab
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                HomeTopBar(leagueName: "Sin liga", userName: userName, selectedTab: $selectedTab)
                VStack(spacing: 16) {
                    ZStack {
                        DSArenaGrid(opacity: 0.4)
                        VStack(spacing: 16) {
                            ZStack {
                                Circle().fill(DS.accentSoft)
                                    .frame(width: 64, height: 64)
                                    .overlay(Circle().stroke(DS.accentLine, lineWidth: 1))
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(DS.accent)
                            }
                            .accessibilityHidden(true)
                            VStack(spacing: 8) {
                                Text(appLang == .es ? "Aún no\ntienes liga" : "You don't have\na league yet")
                                    .font(.bebas(38))
                                    .tracking(-1)
                                    .foregroundStyle(DS.fg)
                                    .multilineTextAlignment(.center)
                                Text(appLang == .es ? "Únete con un código o crea la tuya\ny empieza la temporada." : "Join with a code or create your own\nand start the season.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(DS.fg2)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(28)
                    }
                    .dsCard()
                    .padding(.horizontal, 20)

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
                    .padding(.horizontal, 20)

                    DSSectionRow(title: appLang == .es ? "Mientras tanto" : "Meanwhile")
                    TutorialCard()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
        }
    }
}

private struct TutorialCard: View {
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @AppStorage("hasSeenTour") private var hasSeenTour: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.fg3)
                    .accessibilityHidden(true)
                DSEyebrow(text: appLang == .es ? "Cómo funciona" : "How it works")
            }
            Text(appLang == .es ? "Crea o únete a una liga · recibe puntos virtuales · aposta en partidos reales · sube en el ranking · reta 1v1 en el Arena." : "Create or join a league · earn virtual points · bet on real matches · climb the rankings · challenge 1v1 in the Arena.")
                .font(.system(size: 13))
                .foregroundStyle(DS.fg2)
                .lineSpacing(3)
            HStack(spacing: 6) {
                ForEach(["LIGA", "BALANCE", "PICK", "ARENA"], id: \.self) { tag in
                    DSPill(text: tag, fontSize: 9)
                }
            }
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                hasSeenTour = false
            } label: {
                HStack(spacing: 8) {
                    Text(appLang == .es ? "Ver instrucciones" : "View instructions")
                        .font(.system(size: 13, weight: .black))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .black))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(DS.accentInk)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(DS.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .background(DS.bg1)
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
            .strokeBorder(DS.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }
}

// MARK: - State 2: Dashboard
private struct HomeDashboardView: View {
    let league: FriendLeague
    let userName: String
    let myBalance: Int
    let myDeltaToday: Int
    let myRank: Int?
    let totalMembers: Int
    let hitRate: Int
    let remainingBetsToday: Int
    @Binding var selectedTab: BetsyTab
    @EnvironmentObject var leagueService: LeagueService
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    private let sparkData: [CGFloat] = [22, 18, 24, 14, 16, 10, 18, 8, 12, 4, 6, 2]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                HomeTopBar(leagueName: league.name, userName: userName, selectedTab: $selectedTab)

                VStack(spacing: 0) {
                    BalanceHeroCard(
                        balance: myBalance,
                        deltaToday: myDeltaToday,
                        sparkData: sparkData
                    )
                    .padding(.horizontal, 20).padding(.bottom, 12)

                    StatsRow(
                        rank: myRank,
                        totalMembers: totalMembers,
                        hitRate: hitRate,
                        remainingBetsToday: remainingBetsToday
                    )
                    .padding(.horizontal, 20).padding(.bottom, 14)

                DSButton(title: appLang == .es ? "Apostar →" : "Bet →", style: .primary, fullWidth: true, height: 56) {
                        selectedTab = .play
                    }
                    .padding(.horizontal, 20).padding(.bottom, 4)

                    DSSectionRow(title: appLang == .es ? "Hoy en tu liga" : "Today in your league", action: appLang == .es ? "Ver todo" : "See all") { selectedTab = .play }
                    TodayMatchesScroll(selectedTab: $selectedTab, league: league)
                        .padding(.bottom, 4)

                    DSSectionRow(title: appLang == .es ? "Clasificación" : "Rankings", action: appLang == .es ? "Completa →" : "Full →") { selectedTab = .league }
                    LeaderboardPreviewCard(league: league, myUid: leagueService.currentUserId)
                        .environmentObject(leagueService)
                        .padding(.horizontal, 20).padding(.bottom, leagueService.activeArena == nil ? 20 : 4)

                    if let arena = leagueService.activeArena {
                        DSSectionRow(title: appLang == .es ? "Tu duelo activo" : "Your active duel")
                        ActiveDuelCard(duel: arena, myUid: leagueService.currentUserId)
                            .padding(.horizontal, 20).padding(.bottom, 20)
                    }
                }
            }
        }
    }
}

private struct BalanceHeroCard: View {
    let balance: Int
    let deltaToday: Int
    let sparkData: [CGFloat]
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    private var deltaSign: String { deltaToday >= 0 ? "+" : "" }
    private var deltaColor: Color { deltaToday >= 0 ? DS.win : DS.loss }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle().fill(DS.accentSoft).frame(width: 180)
                .blur(radius: 50).offset(x: 40, y: -40)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    DSEyebrow(text: appLang == .es ? "Tu saldo" : "Your balance")
                    Spacer()
                    DSPill(text: appLang == .es ? "\(deltaSign)\(deltaToday) hoy" : "\(deltaSign)\(deltaToday) today",
                           bg: deltaColor.opacity(0.1), border: deltaColor.opacity(0.3),
                           fg: deltaColor, fontSize: 10)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(balance)")
                        .font(.bebas(68)).tracking(-2).foregroundStyle(DS.fg)
                    Text("pts").font(.system(size: 22)).foregroundStyle(DS.fg3)
                }
                .padding(.top, 6)
                DSSparkline(points: sparkData, color: DS.accent)
                    .frame(height: 32).padding(.top, 12)
            }
            .padding(20)
        }
        .dsCard()
    }
}

private struct StatsRow: View {
    let rank: Int?
    let totalMembers: Int
    let hitRate: Int
    let remainingBetsToday: Int
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    var body: some View {
        HStack(spacing: 10) {
            StatBox(
                label: appLang == .es ? "Posición" : "Rank",
                value: rank.map { "\($0)º" } ?? "—",
                sub: totalMembers > 0 ? (appLang == .es ? "de \(totalMembers)" : "of \(totalMembers)") : (appLang == .es ? "sin datos" : "no data"),
                isAccent: false
            )
            StatBox(label: appLang == .es ? "Acierto" : "Accuracy", value: "\(hitRate)%", sub: hitRate == 0 ? (appLang == .es ? "sin cerrar" : "no results") : (appLang == .es ? "apuestas" : "bets"), isAccent: false)
            StatBox(label: appLang == .es ? "Hoy" : "Today", value: "\(remainingBetsToday)", sub: appLang == .es ? "bets disp." : "bets left", isAccent: true)
        }
    }
}

private struct StatBox: View {
    let label: String; let value: String; let sub: String; let isAccent: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSEyebrow(text: label)
            Text(value)
                .font(.bebas(28)).tracking(-1)
                .foregroundStyle(isAccent ? DS.accent : DS.fg)
            Text(sub).font(.system(size: 11)).foregroundStyle(DS.fg3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(isAccent ? DS.accentSoft : DS.bg1)
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
            .stroke(isAccent ? DS.accentLine : DS.line, lineWidth: 1))
    }
}

private struct TodayMatchesScroll: View {
    @Binding var selectedTab: BetsyTab
    let league: FriendLeague
    @StateObject private var apiManager = APIManager()
    @AppStorage("isDevModeActive") private var isDevModeActive = false

    private var sportKeys: [String] {
        let keys = league.settings.allowedCompetitions.flatMap(\.sportKeys)
        return keys.isEmpty ? ["basketball_nba", "soccer_spain_la_liga", "soccer_epl"] : Array(Set(keys))
    }

    private var matches: [Match] {
        Array(apiManager.matches.sorted {
            ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture)
        }.prefix(4))
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if !isDevModeActive {
                    ProductionMatchPreviewCard()
                } else if matches.isEmpty {
                    MatchPreviewEmptyCard()
                } else {
                    ForEach(matches) { match in
                        Button {
                            selectedTab = .play
                            let key = homeMatchNavigationKey(match)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                NotificationCenter.default.post(name: .betsyOpenMatch, object: key)
                            }
                        } label: {
                            MatchPreviewCard(match: match)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            guard isDevModeActive else {
                apiManager.matches = []
                return
            }
            apiManager.fetchRealOddsMulti(keys: sportKeys, force: false)
        }
    }
}

private struct ProductionMatchPreviewCard: View {
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DSEyebrow(text: appLang == .es ? "Próximamente" : "Coming soon")
            Text(appLang == .es ? "Mercados no disponibles" : "Markets unavailable")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DS.fg)
            Text(appLang == .es
                 ? "Los partidos aparecerán cuando conectemos las APIs reales."
                 : "Matches will appear once real sports APIs are connected.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.fg3)
                .lineLimit(3)
        }
        .frame(width: 220, alignment: .leading)
        .frame(minHeight: 116, alignment: .leading)
        .padding(14)
        .dsCard()
    }
}

private struct MatchPreviewEmptyCard: View {
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DSEyebrow(text: appLang == .es ? "Simulado" : "Loading")
            Text(appLang == .es ? "Cargando partidos…" : "Loading matches…")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DS.fg)
            ProgressView().tint(DS.accent)
        }
        .frame(width: 200, alignment: .leading)
        .frame(minHeight: 116, alignment: .leading)
        .padding(14)
        .dsCard()
    }
}

private struct MatchPreviewCard: View {
    let match: Match

    private var firstOdd: Odd? { match.odds.first }
    private var secondOdd: Odd? { match.odds.dropFirst().first }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(homeMatchTime(match.startDate))
                    .textCase(.uppercase)
                    .font(.jbMono(11, weight: .semibold)).foregroundStyle(DS.fg3)
                Spacer()
                Text(match.league).textCase(.uppercase)
                    .font(.jbMono(11, weight: .semibold)).foregroundStyle(DS.accent)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                DSCrest(team: homeTeamCode(match.home), size: 28)
                Text("vs").font(.system(size: 13, weight: .bold)).foregroundStyle(DS.fg2)
                DSCrest(team: homeTeamCode(match.away), size: 28)
            }
            Text("\(match.home) vs \(match.away)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DS.fg)
                .lineLimit(1)
            HStack(spacing: 6) {
                OddsChipView(label: firstOdd?.label ?? "1", value: firstOdd.map { String(format: "%.2f", $0.value) } ?? "—")
                OddsChipView(label: secondOdd?.label ?? "2", value: secondOdd.map { String(format: "%.2f", $0.value) } ?? "—")
            }
        }
        .frame(width: 220)
        .padding(14)
        .dsCard()
    }
}

private func homeTeamCode(_ name: String) -> String {
    let parts = name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    if parts.count >= 2 {
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
    return String(name.prefix(3)).uppercased()
}

private func homeMatchTime(_ date: Date?) -> String {
    guard let date else { return "HOY" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "EEE HH:mm"
    return formatter.string(from: date)
}

private func homeMatchNavigationKey(_ match: Match) -> String {
    match.eventId ?? "\(match.home)|\(match.away)|\(match.league)"
}

private struct OddsChipView: View {
    let label: String; let value: String; var active: Bool = false
    var body: some View {
        HStack {
            Text(label)
                .font(.jbMono(11, weight: .semibold))
                .foregroundStyle(active ? DS.bg.opacity(0.75) : DS.fg3)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(active ? DS.bg : DS.fg)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(active ? DS.fg : DS.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(active ? DS.fg : DS.line, lineWidth: 1))
        .frame(maxWidth: .infinity)
    }
}

private struct LeaderboardPreviewCard: View {
    let league: FriendLeague
    let myUid: String?
    @EnvironmentObject var leagueService: LeagueService
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @AppStorage("profileAvatarImageData") private var legacyAvatarImageData: Data = Data()
    @AppStorage("betsyProfileAvatarStoreDataV1") private var profileAvatarStoreData: Data = Data()

    private var members: [LeagueMember] {
        (leagueService.membersByLeague[league.id] ?? [])
            .sorted { $0.points > $1.points }
    }

    private func avatarImageData(for memberId: String) -> Data? {
        let avatars = ProfileAvatarStore.load(from: profileAvatarStoreData)
        if let data = avatars[memberId], !data.isEmpty {
            return data
        }
        if memberId == myUid,
           leagueService.currentDevProfile == .real,
           !legacyAvatarImageData.isEmpty {
            return legacyAvatarImageData
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if members.isEmpty {
                HStack {
                    Text(appLang == .es ? "Cargando clasificación…" : "Loading rankings…")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.fg3)
                    Spacer()
                    ProgressView().tint(DS.accent).scaleEffect(0.8)
                }
                .padding(16)
            } else {
                ForEach(Array(members.prefix(5).enumerated()), id: \.offset) { idx, member in
                    let isMe = member.id == myUid
                    let delta = member.pointsToday
                    let deltaSign = delta >= 0 ? "+" : ""
                    HStack(spacing: 12) {
                        Text("\(idx + 1)").font(.bebas(18))
                            .foregroundStyle(idx == 0 ? DS.accent : DS.fg3).frame(width: 28)
                        DSAvatar(name: member.name, size: 32, accent: isMe, imageData: avatarImageData(for: member.id))
                        Text(member.name).font(.system(size: 14, weight: .bold)).foregroundStyle(DS.fg)
                        Spacer()
                        Text("\(member.points)").font(.bebas(18)).foregroundStyle(DS.fg)
                        Text("\(deltaSign)\(delta)")
                            .font(.jbMono(11, weight: .semibold))
                            .foregroundStyle(delta >= 0 ? DS.win : DS.loss)
                            .frame(minWidth: 44, alignment: .trailing)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(isMe ? DS.accentSoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .dsCard()
    }
}

private struct IncomingChallengeBanner: View {
    let duel: ArenaDuel
    @EnvironmentObject var leagueService: LeagueService
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @State private var showFull = false

    var body: some View {
        ZStack {
            DSArenaGrid(opacity: 0.3)
            LinearGradient(colors: [DS.arena.opacity(0.18), DS.arena2.opacity(0.08)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    DSPill(text: "ARENA · 1V1",
                           bg: DS.arena.opacity(0.2), border: DS.arena.opacity(0.4),
                           fg: DS.arena, dot: DS.arena)
                    Spacer()
                    Text(appLang == .es ? "Expira en 4h" : "Expires in 4h")
                        .font(.jbMono(11, weight: .semibold))
                        .foregroundStyle(DS.fg3)
                }
                Text(appLang == .es ? "\(duel.challengerName) te\ndesafía." : "\(duel.challengerName)\nchallenges you.")
                    .font(.bebas(32)).tracking(-1).foregroundStyle(DS.fg)
                HStack(spacing: 14) {
                    DSAvatar(name: duel.challengerName, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        DSEyebrow(text: appLang == .es ? "apuesta" : "wager")
                        Text("\(duel.wager) pts")
                            .font(.bebas(26)).foregroundStyle(DS.fg)
                    }
                    Spacer()
                    Rectangle().fill(DS.line).frame(width: 1)
                    VStack(alignment: .trailing, spacing: 2) {
                        DSEyebrow(text: appLang == .es ? "evento" : "event")
                        Text(duel.matches.first.map { "\($0.home) vs \($0.away)" } ?? "Arena 1v1")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(DS.fg)
                        Text(appLang == .es ? "\(duel.matches.count) partido\(duel.matches.count == 1 ? "" : "s")" : "\(duel.matches.count) match\(duel.matches.count == 1 ? "" : "es")")
                            .font(.system(size: 11)).foregroundStyle(DS.fg3)
                    }
                }
                HStack(spacing: 8) {
                    DSButton(title: appLang == .es ? "Aceptar reto" : "Accept challenge", style: .arena, fullWidth: true, height: 48) {
                        showFull = true
                    }
                    DSButton(title: appLang == .es ? "Rechazar" : "Decline", style: .ghost, height: 48) {
                        leagueService.declineArena(duelId: duel.id, leagueId: duel.leagueId)
                    }
                }
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
            .stroke(DS.arena.opacity(0.4), lineWidth: 1))
        .fullScreenCover(isPresented: $showFull) {
            ArenaIncomingScreen(duel: duel, leagueService: leagueService)
        }
    }
}

private struct ActiveDuelCard: View {
    let duel: ArenaDuel
    let myUid: String?
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    private var opponentName: String {
        duel.challengerId == myUid ? duel.opponentName : duel.challengerName
    }

    private var myName: String {
        duel.challengerId == myUid ? duel.challengerName : duel.opponentName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                DSPill(text: appLang == .es ? "EN CURSO" : "IN PROGRESS",
                       bg: DS.arena.opacity(0.14), border: DS.arena.opacity(0.4), fg: DS.arena, fontSize: 9)
                Spacer()
                Text("vs \(opponentName)")
                    .font(.jbMono(11, weight: .semibold)).foregroundStyle(DS.fg3)
            }
            HStack(spacing: 14) {
                DSAvatar(name: myName, size: 36, accent: true)
                VStack(spacing: 2) {
                    Text("\(duel.wager)").font(.bebas(24)).foregroundStyle(DS.accent)
                    Text(appLang == .es ? "APUESTA CADA UNO" : "STAKE EACH")
                        .font(.jbMono(11, weight: .semibold)).foregroundStyle(DS.fg3)
                }
                .frame(maxWidth: .infinity)
                DSAvatar(name: opponentName, size: 36)
            }
            Text(duel.matches.first.map { "\($0.home) vs \($0.away)" } ?? (appLang == .es ? "Arena · Esperando resultado" : "Arena · Awaiting result"))
                .font(.system(size: 12)).foregroundStyle(DS.fg2).frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(14).dsCard()
    }
}
