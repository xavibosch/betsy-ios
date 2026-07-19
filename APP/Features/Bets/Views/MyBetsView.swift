import SwiftUI

// MARK: - BetsyTicketsScreen
struct BetsyTicketsScreen: View {
    @EnvironmentObject var leagueService: LeagueService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLeagueId") private var selectedLeagueId = ""
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @AppStorage("isDevModeActive") private var isDevModeActive = false
    let tickets: [UserTicket]
    var onUpdateTickets: ([UserTicket]) -> Void = { _ in }
    var onSimulateDevDay: () -> Void = {}

    @State private var activeFilter: TicketFilter = .open
    @State private var showLeagueSwitcher = false

    private var leagueName: String {
        activeLeague?.name.lowercased() ?? (appLang == .es ? "sin liga" : "no league")
    }

    private var activeLeague: FriendLeague? {
        ActiveLeagueStore.resolve(from: leagueService.myLeagues, selectedId: selectedLeagueId)
    }

    private var activeLeagueId: String { activeLeague?.id ?? "" }

    private var myBalance: Int {
        guard let league = activeLeague,
              let uid = leagueService.currentUserId else { return 0 }
        return leagueService.membersByLeague[league.id]?.first(where: { $0.id == uid })?.points ?? 0
    }

    private var filteredTickets: [UserTicket] {
        tickets.filter { activeFilter.matches($0) }
    }

    private var netBalance: Int {
        tickets.reduce(0) { partial, ticket in
            if ticket.isWithdrawn {
                return partial + ((ticket.withdrawalAmount ?? 0) - ticket.stake)
            }
            if !ticket.isResultKnown { return partial }
            return partial + (ticket.wasWon ? ticket.potentialNetProfit : -ticket.stake)
        }
    }

    private var hitRate: Int {
        let resolved = tickets.filter { $0.isResultKnown && !$0.isWithdrawn }
        guard !resolved.isEmpty else { return 0 }
        let won = resolved.filter(\.wasWon).count
        return Int((Double(won) / Double(resolved.count) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            statsSummary
            filters
            ticketList
        }
        .background(DS.bg.ignoresSafeArea())
        .onAppear {
            settleTickets(referenceDate: DevSimulationClock.now())
        }
        .onReceive(NotificationCenter.default.publisher(for: .betsyTabReset)) { notif in
            guard let tab = notif.object as? BetsyTab, tab == .tickets else { return }
            activeFilter = .open
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            Button {
                guard !leagueService.myLeagues.isEmpty else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                showLeagueSwitcher = true
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(leagueName)
                        .font(.jbMono(11, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(DS.fg3)
                    HStack(spacing: 5) {
                        Text(appLang == .es ? "Mis apuestas" : "My bets")
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
            Spacer()
            if isDevModeActive {
                #if DEBUG
                Button { onSimulateDevDay() } label: {
                    Text(appLang == .es ? "SIMULAR DÍA" : "SIMULATE DAY")
                        .font(.jbMono(11, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(DS.accentInk)
                        .padding(.horizontal, 10)
                        .frame(height: 44)
                        .background(DS.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                #endif
            }
        }
        .padding(.horizontal, DS.screenHPad)
        .padding(.bottom, 16)
        .sheet(isPresented: $showLeagueSwitcher) {
            LeagueSwitcherSheet(isPresented: $showLeagueSwitcher)
                .environmentObject(leagueService)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var statsSummary: some View {
        HStack(spacing: 0) {
            BetStatCol(label: appLang == .es ? "balance neto" : "net balance", value: netBalance.signedText, color: netBalance >= 0 ? DS.win : DS.loss)
            Divider().background(DS.line).frame(height: 36)
            BetStatCol(label: appLang == .es ? "acierto" : "accuracy", value: "\(hitRate)%", color: DS.fg)
            Divider().background(DS.line).frame(height: 36)
            BetStatCol(label: appLang == .es ? "jugadas" : "placed", value: "\(tickets.count)", color: DS.fg)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(DS.bg1)
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                .stroke(DS.line, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TicketFilter.allCases) { filter in
                    TicketFilterPill(
                        title: "\(filter.title(lang: appLang)) (\(count(for: filter)))",
                        isActive: activeFilter == filter
                    ) {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.2)) { activeFilter = filter }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var ticketList: some View {
        ScrollView {
            VStack(spacing: 10) {
                if filteredTickets.isEmpty {
                    TicketsEmptyState(text: activeFilter.emptyText(lang: appLang))
                        .padding(.top, 8)
                } else {
                    ForEach(filteredTickets) { ticket in
                        RealTicketCard(
                            ticket: ticket,
                            now: DevSimulationClock.now(),
                            onWithdraw: { withdraw(ticket) }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 30)
        }
    }

    private func count(for filter: TicketFilter) -> Int {
        tickets.filter { filter.matches($0) }.count
    }

    private func settleTickets(referenceDate: Date) {
        guard isDevModeActive else { return }
        guard !tickets.isEmpty, !activeLeagueId.isEmpty else { return }
        let eligibleIds = Set(tickets.filter { ticket in
            !ticket.isResultKnown
                && !ticket.isWithdrawn
                && referenceDate.timeIntervalSince(ticket.date) >= 5 * 60
        }.map(\.id))
        guard !eligibleIds.isEmpty else { return }
        let eligibleTickets = tickets.filter { eligibleIds.contains($0.id) }
        let result = TicketSettlementEngine.simulate(
            tickets: eligibleTickets,
            initialPoints: myBalance,
            referenceDate: referenceDate
        )
        guard result.didChange else { return }
        let settledById = Dictionary(uniqueKeysWithValues: result.tickets.map { ($0.id, $0) })
        let merged = tickets.map { settledById[$0.id] ?? $0 }
        onUpdateTickets(merged.sorted { $0.date > $1.date })
        if result.pointsDelta != 0 {
            leagueService.adjustPoints(leagueId: activeLeagueId, delta: result.pointsDelta)
        }
    }

    private func withdraw(_ ticket: UserTicket) {
        guard !activeLeagueId.isEmpty,
              let index = tickets.firstIndex(where: { $0.id == ticket.id }),
              let amount = CashOutRule.amount(for: ticket, now: Date()) else { return }
        var updated = tickets
        updated[index].withdrawnAt = DevSimulationClock.now()
        updated[index].withdrawalAmount = amount
        updated[index].isResultKnown = true
        updated[index].wasWon = false
        onUpdateTickets(updated.sorted { $0.date > $1.date })
        leagueService.adjustPoints(leagueId: activeLeagueId, delta: amount)
    }
}

private enum TicketFilter: String, CaseIterable, Identifiable {
    case open
    case won
    case lost
    case withdrawn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open: return "Abiertas"
        case .won: return "Ganadas"
        case .lost: return "Perdidas"
        case .withdrawn: return "Retiradas"
        }
    }

    func title(lang: AppLang) -> String {
        switch self {
        case .open: return lang == .es ? "Abiertas" : "Open"
        case .won: return lang == .es ? "Ganadas" : "Won"
        case .lost: return lang == .es ? "Perdidas" : "Lost"
        case .withdrawn: return lang == .es ? "Retiradas" : "Withdrawn"
        }
    }

    var emptyText: String {
        switch self {
        case .open: return "No tienes ninguna apuesta abierta"
        case .won: return "No tienes apuestas ganadas"
        case .lost: return "No tienes apuestas perdidas"
        case .withdrawn: return "No tienes apuestas retiradas"
        }
    }

    func emptyText(lang: AppLang) -> String {
        switch self {
        case .open: return lang == .es ? "No tienes ninguna apuesta abierta" : "You have no open bets"
        case .won: return lang == .es ? "No tienes apuestas ganadas" : "You have no won bets"
        case .lost: return lang == .es ? "No tienes apuestas perdidas" : "You have no lost bets"
        case .withdrawn: return lang == .es ? "No tienes apuestas retiradas" : "You have no withdrawn bets"
        }
    }

    func matches(_ ticket: UserTicket) -> Bool {
        switch self {
        case .open:
            return !ticket.isResultKnown && !ticket.isWithdrawn
        case .won:
            return ticket.isResultKnown && ticket.wasWon && !ticket.isWithdrawn
        case .lost:
            return ticket.isResultKnown && !ticket.wasWon && !ticket.isWithdrawn
        case .withdrawn:
            return ticket.isWithdrawn
        }
    }
}

private enum CashOutRule {
    static func amount(for ticket: UserTicket, now: Date) -> Int? {
        guard !ticket.isResultKnown, !ticket.isWithdrawn else { return nil }
        let hasStarted = ticket.selections.compactMap(\.startDate).contains { $0 <= now }
        guard !hasStarted else { return nil }
        let age = now.timeIntervalSince(ticket.date)
        if age <= 5 * 60 { return ticket.stake }
        return max(Int((Double(ticket.stake) * 0.70).rounded()), 1)
    }
}

// MARK: - Stat column
private struct BetStatCol: View {
    let label: String
    let value: String
    var color: Color = DS.fg

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .textCase(.uppercase)
                .font(.jbMono(11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(DS.fg3)
            Text(value)
                .font(.jbMono(26, weight: .black))
                .tracking(-0.3)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TicketFilterPill: View {
    let title: String
    var isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? DS.bg : DS.fg3)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(isActive ? DS.fg : DS.bg2)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isActive ? DS.fg : DS.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct TicketsEmptyState: View {
    let text: String
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "ticket")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(DS.fg3)
            Text(text)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DS.fg)
            Text(appLang == .es ? "Cuando hagas tu primera apuesta, aparecerá aquí." : "Once you place your first bet, it will appear here.")
                .font(.system(size: 12))
                .foregroundStyle(DS.fg3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .dsCard()
    }
}

private struct RealTicketCard: View {
    let ticket: UserTicket
    let now: Date
    let onWithdraw: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @State private var isExpanded = false

    private var selection: BetSelection? { ticket.selections.first }
    private var cashOutAmount: Int? { CashOutRule.amount(for: ticket, now: now) }
    private var isMultiPick: Bool { ticket.selections.count > 1 }

    private var status: (text: String, bg: Color, border: Color, fg: Color, icon: String) {
        if ticket.isWithdrawn {
            return (appLang == .es ? "RETIRADA" : "WITHDRAWN", DS.warn.opacity(0.12), DS.warn.opacity(0.35), DS.warn, "arrow.uturn.backward.circle.fill")
        }
        if !ticket.isResultKnown {
            return (appLang == .es ? "EN JUEGO" : "IN PLAY", ticket.isArena ? DS.arena.opacity(0.15) : DS.accentSoft, ticket.isArena ? DS.arena.opacity(0.35) : DS.accentLine, ticket.isArena ? DS.arena : DS.accent, "clock.fill")
        }
        return ticket.wasWon
            ? (appLang == .es ? "GANADA" : "WON", DS.win.opacity(0.15), DS.win.opacity(0.35), DS.win, "checkmark.circle.fill")
            : (appLang == .es ? "PERDIDA" : "LOST", DS.loss.opacity(0.12), DS.loss.opacity(0.3), DS.loss, "xmark.circle.fill")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: status.icon)
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(status.fg)
                    DSPill(text: status.text, bg: status.bg, border: status.border,
                           fg: status.fg, fontSize: 9)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Estado: \(status.text.lowercased())")
                Spacer()
                Text(ticket.date.shortTicketDate)
                    .textCase(.uppercase)
                    .font(.jbMono(10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(DS.fg3)
            }

            HStack(spacing: 10) {
                DSCrest(team: teamCode(selection?.home ?? "BET"), size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(matchTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.fg)
                    Text(selection?.league ?? "Simulado")
                        .textCase(.uppercase)
                        .font(.jbMono(11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(DS.fg3)
                }
                Spacer()
                if ticket.isArena {
                    DSPill(text: "ARENA", bg: DS.arena.opacity(0.14), border: DS.arena.opacity(0.4), fg: DS.arena, fontSize: 9)
                }
                if isMultiPick {
                    Text(multiPickPillText)
                        .font(.jbMono(10, weight: .bold))
                        .foregroundStyle(DS.fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 34)
                        .background(DS.bg3)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(DS.line2, lineWidth: 1))
                }
                Text("\(ticket.stake) pts")
                    .font(.jbMono(14, weight: .black))
                    .foregroundStyle(DS.fg)
            }
            .padding(.top, 12)

            Divider()
                .background(DS.line)
                .padding(.vertical, 12)

            HStack {
                Text(pickText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.fg)
                    .lineLimit(2)
                Spacer()
                Text(resultText)
                    .font(.jbMono(18, weight: .black))
                    .foregroundStyle(resultColor)
            }

            if isMultiPick {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(isExpanded ? (appLang == .es ? "Ocultar picks" : "Hide picks") : (appLang == .es ? "Ver \(ticket.selections.count) picks" : "View \(ticket.selections.count) picks"))
                            .font(.system(size: 12, weight: .black))
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundStyle(DS.fg)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(DS.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous).stroke(DS.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 12)

                if isExpanded {
                    VStack(spacing: 8) {
                        ForEach(ticket.selections) { selection in
                            TicketSelectionRow(selection: selection)
                        }
                    }
                    .padding(.top, 10)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }

            if let amount = cashOutAmount {
                HoldToWithdrawButton(amount: amount, onConfirm: onWithdraw)
                .padding(.top, 12)
            }
        }
        .padding(14)
        .background(!ticket.isResultKnown ? DS.accentSoft : DS.bg1)
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                .stroke(!ticket.isResultKnown ? DS.accentLine : DS.line, lineWidth: 1)
        )
    }

    private var matchTitle: String {
        guard let selection else { return "Ticket" }
        if ticket.isArena {
            return ticket.contextTitle ?? (appLang == .es ? "Reto Arena" : "Arena challenge")
        }
        if ticket.selections.count > 1 {
            return appLang == .es ? "Apuesta de \(ticket.selections.count) partidos" : "Bet on \(ticket.selections.count) matches"
        }
        return "\(selection.home) vs \(selection.away)"
    }

    private var multiPickPillText: String {
        appLang == .es ? "\(ticket.selections.count) part." : "\(ticket.selections.count) matches"
    }

    private var pickText: String {
        guard let selection else { return appLang == .es ? "Selección pendiente" : "Selection pending" }
        let readable = readableOddLabel(selection.oddLabel, home: selection.home, away: selection.away, lang: appLang)
        if ticket.selections.count > 1 {
            return "\(readable) @ \(selection.oddValue.oddsText) · +\(ticket.selections.count - 1) picks"
        }
        return "\(readable) @ \(selection.oddValue.oddsText)"
    }

    private var resultText: String {
        if ticket.isWithdrawn { return "+\(ticket.withdrawalAmount ?? 0)" }
        if !ticket.isResultKnown { return "+\(ticket.potentialNetProfit)" }
        return ticket.wasWon ? "+\(ticket.potentialNetProfit)" : "-\(ticket.stake)"
    }

    private var resultColor: Color {
        if ticket.isWithdrawn { return DS.warn }
        if !ticket.isResultKnown { return DS.win }
        return ticket.wasWon ? DS.win : DS.loss
    }
}

private struct TicketSelectionRow: View {
    let selection: BetSelection
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    var body: some View {
        HStack(spacing: 10) {
            DSCrest(team: teamCode(selection.home), size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selection.home) vs \(selection.away)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.fg)
                    .lineLimit(1)
                Text(readableOddLabel(selection.oddLabel, home: selection.home, away: selection.away, lang: appLang))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.fg3)
                    .lineLimit(1)
            }
            Spacer()
            Text(selection.oddValue.oddsText)
                .font(.jbMono(13, weight: .black))
                .foregroundStyle(DS.accent)
        }
        .padding(10)
        .background(DS.bg2)
        .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous).stroke(DS.line, lineWidth: 1))
    }
}

private struct HoldToWithdrawButton: View {
    let amount: Int
    let onConfirm: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    @State private var progress: CGFloat = 0
    @State private var isHolding = false
    @State private var didTrigger = false
    @State private var timer: Timer?

    private let holdDuration: TimeInterval = 1.15

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                .fill(DS.bg2)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                    .fill(DS.warn.opacity(0.34))
                    .frame(width: geo.size.width * progress)
                    .animation(reduceMotion ? nil : .linear(duration: 0.02), value: progress)
            }

            HStack(spacing: 9) {
                Image(systemName: isHolding ? "lock.open.fill" : "hand.tap.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(isHolding ? DS.warn : DS.fg3)
                Text(isHolding ? (appLang == .es ? "Mantén…" : "Hold…") : (appLang == .es ? "Retirar · \(amount) pts" : "Withdraw · \(amount) pts"))
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(DS.fg)
                Spacer()
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.jbMono(10, weight: .black))
                    .foregroundStyle(isHolding ? DS.warn : DS.fg3)
            }
            .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous).stroke(DS.warn.opacity(isHolding ? 0.5 : 0.24), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHolding() }
                .onEnded { _ in stopHolding(triggeredByRelease: true) }
        )
        .onDisappear { invalidateTimer() }
        .accessibilityLabel(appLang == .es ? "Retirar \(amount) puntos" : "Withdraw \(amount) points")
        .accessibilityHint(appLang == .es ? "Mantén pulsado para confirmar" : "Hold to confirm")
        .accessibilityValue("\(Int((progress * 100).rounded()))%")
        .accessibilityAddTraits(.isButton)
    }

    private func startHolding() {
        guard timer == nil, !didTrigger else { return }
        isHolding = true
        let startedAt = Date()
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startedAt)
            progress = min(CGFloat(elapsed / holdDuration), 1)
            if progress >= 1, !didTrigger {
                didTrigger = true
                timer.invalidate()
                self.timer = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onConfirm()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    reset()
                }
            }
        }
    }

    private func stopHolding(triggeredByRelease: Bool) {
        guard !didTrigger else { return }
        invalidateTimer()
        if triggeredByRelease, progress > 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            progress = 0
            isHolding = false
        }
    }

    private func reset() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            progress = 0
            isHolding = false
            didTrigger = false
        }
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
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

private extension Int {
    var signedText: String { self >= 0 ? "+\(self)" : "\(self)" }
}

private extension Double {
    var oddsText: String { String(format: "%.2f", self) }
}

private extension Date {
    var shortTicketDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = Calendar.current.isDateInToday(self) ? "'HOY' HH:mm" : "dd MMM"
        return formatter.string(from: self)
    }
}
