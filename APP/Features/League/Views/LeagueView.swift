import SwiftUI

// MARK: - Navigation state
private enum LeagueNav: Equatable {
    case list, create, detail
}

// MARK: - Root screen

struct BetsyLeagueScreen: View {
    @EnvironmentObject var leagueService: LeagueService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLeagueId") private var selectedLeagueId = ""
    @AppStorage("betsyLeagueNavState") private var savedNavState = "list"
    @State private var nav: LeagueNav = .list
    @State private var createStep: Int = 1
    @State private var showJoinSheet = false

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            switch nav {
            case .list:
                LeagueListView(
                    showJoinSheet: $showJoinSheet,
                    onCreate: {
                        nav = .create
                        savedNavState = "create"
                        createStep = 1
                    },
                    onDetail: {
                        nav = .detail
                        savedNavState = "detail"
                    }
                )
                .transition(.opacity)
            case .create:
                CreateLeagueView(
                    step: $createStep,
                    onBack: {
                        if createStep > 1 {
                            createStep -= 1
                        } else {
                            nav = .list
                            savedNavState = "list"
                        }
                    },
                    onFinish: {
                        nav = .list
                        savedNavState = "list"
                    }
                )
                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            case .detail:
                LeagueDetailView(onBack: {
                    nav = .list
                    savedNavState = "list"
                })
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88), value: nav)
        .onAppear {
            if !selectedLeagueId.isEmpty, savedNavState != "create" {
                nav = .detail
            } else if savedNavState == "create" {
                nav = .create
            } else {
                nav = .list
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .betsyTabReset)) { notif in
            guard let tab = notif.object as? BetsyTab, tab == .league else { return }
            createStep = 1
            showJoinSheet = false
            if nav != .list {
                withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88)) { nav = .list }
            }
            savedNavState = "list"
        }
        .onReceive(NotificationCenter.default.publisher(for: .betsyOpenCreateLeague)) { _ in
            guard nav == .list else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88)) {
                nav = .create
                savedNavState = "create"
                createStep = 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .betsyOpenJoinLeague)) { _ in
            guard nav == .list else { return }
            showJoinSheet = true
        }
    }
}

// MARK: - League list (ScreenLeagueList)

private struct LeagueListView: View {
    @EnvironmentObject var leagueService: LeagueService
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @AppStorage("selectedLeagueId") private var selectedLeagueId = ""
    @Binding var showJoinSheet: Bool
    let onCreate: () -> Void
    let onDetail: () -> Void

    private var activeLeague: FriendLeague? {
        ActiveLeagueStore.resolve(from: leagueService.myLeagues, selectedId: selectedLeagueId)
    }
    private var otherLeagues: [FriendLeague] {
        guard let activeLeague else { return leagueService.myLeagues }
        return leagueService.myLeagues.filter { $0.id != activeLeague.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appLang == .es ? "tus competiciones" : "your competitions")
                            .font(.jbMono(11, weight: .semibold))
                            .tracking(1.8)
                            .foregroundStyle(DS.fg3)
                        Text(appLang == .es ? "Mis ligas" : "My leagues")
                            .font(.bebas(32))
                            .tracking(-0.5)
                            .foregroundStyle(DS.fg)
                    }
                    Spacer()
                    Button(action: onCreate) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.fg)
                            .frame(width: 40, height: 40)
                            .background(DS.bg2)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(DS.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Crear liga")
                }
                .padding(.horizontal, DS.screenHPad)
                .padding(.bottom, 16)

                if !leagueService.myLeagues.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(leagueService.myLeagues) { league in
                            ActiveLeagueCard(
                                league: league,
                                isSelected: league.id == selectedLeagueId,
                                onDetailTap: {
                                    selectedLeagueId = league.id
                                    leagueService.loadMembers(for: league)
                                    leagueService.listenForArena(leagueId: league.id)
                                    onDetail()
                                }
                            )
                            .environmentObject(leagueService)
                            .onAppear { leagueService.loadMembers(for: league) }
                        }
                    }
                    .padding(.horizontal, 20)
                } else if leagueService.isLoading {
                    HStack {
                        ProgressView().tint(DS.accent)
                        Text(appLang == .es ? "Cargando ligas…" : "Loading leagues…")
                            .font(.system(size: 13)).foregroundStyle(DS.fg3)
                    }
                    .padding(.horizontal, 20)
                } else {
                    // No leagues state
                    VStack(spacing: 12) {
                        Image(systemName: "trophy")
                            .font(.system(size: 28)).foregroundStyle(DS.fg3)
                        Text(appLang == .es ? "Sin liga seleccionada" : "No selected league")
                            .font(.bebas(24)).foregroundStyle(DS.fg)
                        Text(appLang == .es ? "Crea una liga o únete con un código de invitación." : "Create a league or join with an invite code.")
                            .font(.system(size: 13)).foregroundStyle(DS.fg3)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                    .dsCard()
                    .padding(.horizontal, 20)
                }

                HStack(spacing: 10) {
                    LeagueActionCard(
                        icon: "person.badge.plus",
                        title: appLang == .es ? "Unirse" : "Join",
                        subtitle: appLang == .es ? "Con código" : "With code",
                        accent: false,
                        action: { showJoinSheet = true }
                    )
                    LeagueActionCard(
                        icon: "plus.circle.fill",
                        title: appLang == .es ? "Crear" : "Create",
                        subtitle: appLang == .es ? "Nueva liga" : "New league",
                        accent: true,
                        action: onCreate
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
        }
        .background(DS.bg.ignoresSafeArea())
        .sheet(isPresented: $showJoinSheet) {
            JoinLeagueSheet(isPresented: $showJoinSheet)
                .environmentObject(leagueService)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Join sheet

private struct JoinLeagueSheet: View {
    @EnvironmentObject var leagueService: LeagueService
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @AppStorage("selectedLeagueId") private var selectedLeagueId = ""
    @Binding var isPresented: Bool
    @State private var code = ""

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            DSArenaGrid(opacity: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appLang == .es ? "CÓDIGO DE ACCESO" : "ACCESS CODE")
                            .font(.jbMono(10, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(DS.fg3)
                        Text(appLang == .es ? "Únete a una liga" : "Join a league")
                            .font(.bebas(36))
                            .tracking(-0.7)
                            .foregroundStyle(DS.fg)
                    }
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(DS.fg)
                            .frame(width: 44, height: 44)
                            .background(DS.bg2)
                            .clipShape(RoundedRectangle(cornerRadius: DS.rSm, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: DS.rSm, style: .continuous).stroke(DS.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cerrar")
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appLang == .es ? "Pega el código que te ha pasado el admin" : "Paste the code your admin shared")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.fg2)
                        Text(appLang == .es ? "Al entrar, esta liga quedará seleccionada para apostar, competir y retar en Arena." : "When you join, this league becomes selected for betting, competing and Arena challenges.")
                            .font(.system(size: 12))
                            .lineSpacing(3)
                            .foregroundStyle(DS.fg3)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(appLang == .es ? "CÓDIGO" : "CODE")
                            .font(.jbMono(10, weight: .semibold))
                            .tracking(1.8)
                            .foregroundStyle(DS.fg3)
                        TextField("GLX-7K2", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.jbMono(22, weight: .bold))
                            .foregroundStyle(DS.fg)
                            .padding(.horizontal, 16)
                            .frame(height: 58)
                            .background(DS.bg2)
                            .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous).stroke(DS.line2, lineWidth: 1))
                    }

                    DSButton(title: appLang == .es ? "Unirme a la liga →" : "Join league →", style: .primary, fullWidth: true, height: 56) {
                        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        selectedLeagueId = clean
                        leagueService.joinLeague(code: clean)
                        isPresented = false
                    }
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)
                    .opacity(code.trimmingCharacters(in: .whitespacesAndNewlines).count < 4 ? 0.45 : 1)
                }
                .padding(18)
                .dsCard()
                .padding(.horizontal, 20)
                .padding(.top, 26)

                Spacer()
            }
        }
    }
}

// MARK: - Active league card

private struct ActiveLeagueCard: View {
    @EnvironmentObject var leagueService: LeagueService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    let league: FriendLeague
    let isSelected: Bool
    let onDetailTap: () -> Void
    @State private var showCopiedToast = false

    private var myMember: LeagueMember? {
        guard let uid = leagueService.currentUserId else { return nil }
        return leagueService.membersByLeague[league.id]?.first(where: { $0.id == uid })
    }

    private var myRank: Int? {
        guard let uid = leagueService.currentUserId else { return nil }
        let sorted = (leagueService.membersByLeague[league.id] ?? []).sorted { $0.points > $1.points }
        return sorted.firstIndex(where: { $0.id == uid }).map { $0 + 1 }
    }

    private var competitionLabel: String {
        league.settings.allowedCompetitions.map { $0.title(lang: appLang) }.joined(separator: " · ")
    }

    private func copyCode() {
        UIPasteboard.general.string = league.code
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(notification: .announcement, argument: appLang == .es ? "Código copiado" : "Code copied")
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2)) { showCopiedToast = false }
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(DS.accentSoft)
                .frame(width: 140, height: 140)
                .offset(x: 30, y: -30)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    DSPill(
                        text: isSelected ? (appLang == .es ? "SELECCIONADA" : "SELECTED") : (appLang == .es ? "LIGA" : "LEAGUE"),
                        bg: isSelected ? DS.accentSoft : DS.bg2,
                        border: isSelected ? DS.accentLine : DS.line,
                        fg: isSelected ? DS.accent : DS.fg2,
                        fontSize: 11,
                        dot: isSelected ? DS.accent : nil
                    )
                    Spacer()
                Text(appLang == .es ? "\(league.members) jugadores" : "\(league.members) players")
                        .font(.jbMono(10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(DS.fg3)
                }

                Text(league.name)
                    .font(.bebas(24))
                    .tracking(-0.3)
                    .foregroundStyle(DS.fg)
                    .padding(.top, 14)

                Text(competitionLabel.isEmpty ? (appLang == .es ? "Todas las competiciones" : "All competitions") : competitionLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.fg2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                HStack {
                    LeagueStatCol(
                        label: appLang == .es ? "posición" : "position",
                        value: myRank.map { "\($0)º" } ?? "—",
                        accent: false
                    )
                    Spacer()
                    LeagueStatCol(
                        label: "balance",
                        value: myMember.map { "\($0.points)" } ?? "—",
                        accent: false
                    )
                    Spacer()
                    Button(action: copyCode) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(appLang == .es ? "CÓDIGO" : "CODE")
                                    .font(.jbMono(11, weight: .semibold))
                                    .tracking(1.4)
                                    .foregroundStyle(DS.fg3)
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(DS.accent)
                            }
                            Text(league.code)
                                .font(.jbMono(26, weight: .black))
                                .tracking(-0.3)
                                .foregroundStyle(DS.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(appLang == .es ? "Copiar código de liga \(league.code)" : "Copy league code \(league.code)")
                }
                .padding(.top, 14)

                DSButton(title: isSelected
                         ? (appLang == .es ? "Ver clasificación →" : "View leaderboard →")
                         : (appLang == .es ? "Seleccionar y ver →" : "Select and view →"),
                         style: .primary,
                         fullWidth: true,
                         action: onDetailTap)
                    .padding(.top, 16)
            }
            .padding(18)

            if showCopiedToast {
                Text(appLang == .es ? "Código copiado" : "Code copied")
                    .font(.jbMono(11, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(DS.accentInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(DS.accent)
                    .clipShape(Capsule())
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(DS.bg1)
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                .stroke(isSelected ? DS.accentLine : DS.line, lineWidth: 1)
        )
        .clipped()
    }
}

private struct LeagueStatCol: View {
    let label: String
    let value: String
    var accent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .textCase(.uppercase)
                .font(.jbMono(11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(DS.fg3)
            Text(value)
                .font(.jbMono(26, weight: .black))
                .tracking(-0.3)
                .foregroundStyle(accent ? DS.accent : DS.fg)
        }
    }
}

// MARK: - Other league row

private struct OtherLeagueRow: View {
    let initials: String
    let name: String
    let meta: String
    let pills: [String]
    let warnPill: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DS.bg3)
                        Text(initials)
                            .font(.jbMono(16, weight: .black))
                            .foregroundStyle(DS.fg)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DS.fg)
                        Text(meta)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.fg3)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.fg3)
                }

                if !pills.isEmpty || warnPill != nil {
                    HStack(spacing: 6) {
                        ForEach(pills, id: \.self) { p in
                            DSPill(text: p, fontSize: 10)
                        }
                        if let wp = warnPill {
                            DSPill(text: wp, bg: DS.warn.opacity(0.15),
                                   border: DS.warn.opacity(0.35), fg: DS.warn, fontSize: 10)
                        }
                    }
                }
            }
            .padding(16)
            .dsCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create League Wizard

private struct CreateLeagueView: View {
    @EnvironmentObject var leagueService: LeagueService
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @AppStorage("selectedLeagueId") private var selectedLeagueId = ""
    @Binding var step: Int
    let onBack: () -> Void
    let onFinish: () -> Void

    @State private var draft = LeagueCreateDraft()
    @State private var showExitConfirm = false

    private var hasUnsavedData: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var stepLabel: String {
        let labels = appLang == .es
            ? ["Básico", "Deportes", "Ventana", "Economía"]
            : ["Basics", "Sports", "Window", "Economy"]
        return labels[max(0, step - 1)]
    }

    private var stepTitle: String {
        if appLang == .es {
            switch step {
            case 1: return "Datos\nbásicos"
            case 2: return "¿A qué\njugaréis?"
            case 3: return "Días de\njuego"
            default: return "Economía\ndel juego"
            }
        } else {
            switch step {
            case 1: return "Basic\ndata"
            case 2: return "What will\nyou play?"
            case 3: return "Game\ndays"
            default: return "Game\neconomy"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 10)

            // Nav header
            HStack {
                Button {
                    if step == 1 && hasUnsavedData {
                        showExitConfirm = true
                    } else {
                        onBack()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.fg)
                        .dsBackButton()
                }
                .buttonStyle(.plain)
                Spacer()
                Text(appLang == .es ? "paso \(step) de 4" : "step \(step) of 4")
                    .font(.jbMono(11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(DS.fg3)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Progress bar
            HStack(spacing: 4) {
                ForEach(1...4, id: \.self) { s in
                    Capsule()
                        .fill(s <= step ? DS.accent : DS.bg3)
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 20)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(appLang == .es ? "Progreso de creación de liga" : "League creation progress")
            .accessibilityValue(appLang == .es ? "Paso \(step) de 4: \(stepLabel)" : "Step \(step) of 4: \(stepLabel)")

            // Title block
            VStack(alignment: .leading, spacing: 4) {
                Text(stepLabel)
                    .textCase(.uppercase)
                    .font(.jbMono(11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(DS.fg3)
                Text(stepTitle)
                    .font(.bebas(34))
                    .tracking(-0.5)
                    .foregroundStyle(DS.fg)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        switch step {
                        case 1: CreateStep1Content(draft: $draft)
                        case 2: CreateStep2Content(draft: $draft)
                        case 3: CreateStep3Content(draft: $draft)
                        default: CreateStep4Content(draft: $draft)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 16)
                }
            }

            // Footer
            Rectangle()
                .fill(DS.line)
                .frame(height: 1)

            Group {
                switch step {
                case 1:
                    DSButton(title: appLang == .es ? "Siguiente →" : "Next →", style: .primary, fullWidth: true,
                             action: { step = 2 })
                        .disabled(!draft.isBasicStepValid)
                        .opacity(draft.isBasicStepValid ? 1 : 0.45)
                        .accessibilityHint(draft.isBasicStepValid
                                           ? (appLang == .es ? "Continúa al paso de deportes" : "Continue to the sports step")
                                           : (appLang == .es ? "Completa el nombre y los datos básicos de la liga" : "Complete the league name and basic data"))
                case 4:
                    DSButton(title: appLang == .es ? "Crear liga" : "Create league", style: .primary, fullWidth: true) {
                        leagueService.createLeague(request: draft.request)
                        onFinish()
                    }
                    .disabled(!draft.isReadyToCreate)
                    .opacity(draft.isReadyToCreate ? 1 : 0.45)
                    .accessibilityHint(draft.isReadyToCreate
                                       ? (appLang == .es ? "Crea la liga con estos ajustes" : "Create the league with these settings")
                                       : (appLang == .es ? "Completa todos los pasos antes de crear la liga" : "Complete all steps before creating the league"))
                default:
                    DSButton(title: appLang == .es ? "Siguiente →" : "Next →", style: .primary, fullWidth: true,
                             action: { step += 1 })
                        .disabled(!isCurrentStepValid)
                        .opacity(isCurrentStepValid ? 1 : 0.45)
                        .accessibilityHint(isCurrentStepValid
                                           ? (appLang == .es ? "Continúa al siguiente paso" : "Continue to the next step")
                                           : (appLang == .es ? "Completa la configuración actual para continuar" : "Complete the current setup to continue"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(DS.bg1)
        }
        .background(DS.bg.ignoresSafeArea())
        .alert(appLang == .es ? "¿Salir sin guardar?" : "Exit without saving?", isPresented: $showExitConfirm) {
            Button(appLang == .es ? "Salir" : "Exit", role: .destructive, action: onBack)
            Button(appLang == .es ? "Continuar editando" : "Keep editing", role: .cancel) {}
        } message: {
            Text(appLang == .es
                 ? "Perderás la configuración de la liga que estabas creando."
                 : "You'll lose the league configuration you were setting up.")
        }
    }

    private var isCurrentStepValid: Bool {
        switch step {
        case 1: return draft.isBasicStepValid
        case 2: return draft.isCompetitionsStepValid
        case 3: return draft.isWindowStepValid
        case 4: return draft.isEconomyStepValid
        default: return true
        }
    }
}

// MARK: - League action card (Crear / Unirse)

private struct LeagueActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var accent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accent ? DS.accent : DS.bg3)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent ? DS.accentInk : DS.fg)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.fg)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.fg3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .frame(minHeight: 100)
            .background(accent ? DS.accentSoft : DS.bg1)
            .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                    .stroke(accent ? DS.accentLine : DS.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Simple wrapping flow layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? 300
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxW && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            rowH = max(rowH, s.height); x += s.width + spacing
        }
        return CGSize(width: maxW, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            sv.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            rowH = max(rowH, s.height); x += s.width + spacing
        }
    }
}

// MARK: - Step 1: Datos básicos

private struct CreateStep1Content: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @Binding var draft: LeagueCreateDraft
    private let sizes = [2, 4, 6, 8, 10, 20]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                DSEyebrow(text: appLang == .es ? "Nombre de la liga" : "League name")
                TextField("Los Galácticos", text: $draft.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DS.fg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(DS.bg1)
                    .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                            .stroke(DS.accentLine, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                DSEyebrow(text: appLang == .es ? "Participantes máx." : "Max players")
                FlowLayout(spacing: 6) {
                    ForEach(sizes, id: \.self) { n in
                        let sel = n == draft.maxParticipantsSelection
                        Button(action: { draft.maxParticipantsSelection = n }) {
                            Text("\(n)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(sel ? DS.fg : DS.fg2)
                                .frame(minWidth: 48, minHeight: 40)
                                .padding(.horizontal, 14)
                                .background(sel ? DS.bg2 : DS.bg1)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(sel ? DS.accent : DS.line, lineWidth: sel ? 1.5 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Access code (auto-generated server-side at creation)
            VStack(alignment: .leading, spacing: 8) {
                DSEyebrow(text: appLang == .es ? "Código de acceso" : "Access code")
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appLang == .es ? "Se generará automáticamente" : "It will be generated automatically")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DS.fg)
                        Text(appLang == .es ? "Lo verás justo después de crear la liga." : "You will see it right after creating the league.")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.fg3)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(DS.bg1)
                .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                        .stroke(DS.line2, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                )
            }
        }
    }
}

// MARK: - Step 2: Deportes

private struct CreateStep2Content: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @Binding var draft: LeagueCreateDraft
    private let sports: [(LeagueCompetition, String)] = [
        (.nba, "🏀"), (.laLiga, "⚽"),
        (.premier, "⚽"), (.bundesliga, "⚽"),
        (.serieA, "⚽"), (.ligue1, "⚽"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appLang == .es
                 ? "Las competiciones que selecciones serán las únicas disponibles para apostar en esta liga."
                 : "The competitions you select will be the only ones available for betting in this league.")
                .font(.system(size: 13))
                .foregroundStyle(DS.fg2)
                .padding(.bottom, 6)

            ForEach(sports, id: \.0) { competition, emoji in
                let sel = draft.allowedCompetitions.contains(competition)
                Button(action: {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.2)) {
                        if sel, draft.allowedCompetitions.count > 1 {
                            draft.allowedCompetitions.remove(competition)
                        } else {
                            draft.allowedCompetitions.insert(competition)
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(DS.bg2)
                            Text(emoji).font(.system(size: 18))
                                .accessibilityHidden(true)
                        }
                        .frame(width: 36, height: 36)
                        Text(competition.title(lang: appLang))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DS.fg)
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(sel ? DS.accent : Color.clear)
                                .frame(width: 24, height: 24)
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(sel ? DS.accent : DS.line2, lineWidth: 1.5)
                                .frame(width: 24, height: 24)
                            if sel {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(DS.accentInk)
                            }
                        }
                    }
                    .padding(14)
                    .background(sel ? DS.bg2 : DS.bg1)
                    .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                            .stroke(sel ? DS.accent : DS.line, lineWidth: sel ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Step 3: Ventana

private struct CreateStep3Content: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @Binding var draft: LeagueCreateDraft
    private var windows: [(LeagueBetWindowPreset, String, String)] {
        if appLang == .es {
            return [
                (.daily, "Todos los días", "Lun · Mar · Mié · Jue · Vie · Sáb · Dom"),
                (.weekend, "Solo fines de semana", "Sáb · Dom"),
                (.custom, "Personalizado", "Tú eliges los días"),
            ]
        }
        return [
            (.daily, "Every day", "Mon · Tue · Wed · Thu · Fri · Sat · Sun"),
            (.weekend, "Weekends only", "Sat · Sun"),
            (.custom, "Custom", "You choose the days"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appLang == .es ? "Define cuándo se pueden colocar apuestas estándar." : "Define when standard bets can be placed.")
                .font(.system(size: 13))
                .foregroundStyle(DS.fg2)
                .padding(.bottom, 6)

            ForEach(windows, id: \.0) { item in
                let sel = item.0 == draft.betWindowPreset
                Button(action: { withAnimation(reduceMotion ? nil : .spring(response: 0.2)) { draft.betWindowPreset = item.0 } }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.1)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(DS.fg)
                            Text(item.2)
                                .font(.system(size: 12))
                                .foregroundStyle(DS.fg3)
                        }
                        Spacer()
                        ZStack {
                            Circle().stroke(sel ? DS.accent : DS.line2, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                            if sel {
                                Circle().fill(DS.accent).frame(width: 12, height: 12)
                            }
                        }
                    }
                    .padding(16)
                    .background(sel ? DS.bg2 : DS.bg1)
                    .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                            .stroke(sel ? DS.accent : DS.line, lineWidth: sel ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
            }

            // Custom day picker (shown when Personalizado/Custom selected)
            if draft.betWindowPreset == .custom {
                VStack(alignment: .leading, spacing: 10) {
                    DSEyebrow(text: appLang == .es ? "Elige los días con partidos" : "Choose match days")
                    HStack(spacing: 0) {
                        ForEach(LeagueWeekday.allCases) { day in
                            let sel = draft.activeWeekdays.contains(day)
                            Button {
                                withAnimation(reduceMotion ? nil : .spring(response: 0.2)) {
                                    if sel && draft.activeWeekdays.count > 1 {
                                        draft.activeWeekdays.remove(day)
                                    } else {
                                        draft.activeWeekdays.insert(day)
                                    }
                                }
                            } label: {
                                Text(day.shortTitle(lang: appLang))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(sel ? DS.fg : DS.fg3)
                                    .frame(width: 36, height: 36)
                                    .background(sel ? DS.bg2 : DS.bg1)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(sel ? DS.accent : DS.line, lineWidth: sel ? 1.5 : 1))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if draft.activeWeekdays.isEmpty {
                        Text(appLang == .es ? "Selecciona al menos un día" : "Select at least one day")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.loss)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(DS.bg1)
                .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                    .stroke(DS.accentLine, lineWidth: 1))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Arena toggle
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        DSPill(text: "ARENA", bg: DS.arena.opacity(0.15),
                               border: DS.arena.opacity(0.35), fg: DS.arena, fontSize: 9)
                        Text(appLang == .es ? "Retos 1v1 fuera de ventana" : "1v1 challenges outside window")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DS.fg)
                    }
                    Text(appLang == .es ? "Permite duelos cualquier día." : "Allow duels any day.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.fg3)
                }
                Spacer()
                ZStack(alignment: draft.challengesOutsideBetWindow ? .trailing : .leading) {
                    Capsule().fill(draft.challengesOutsideBetWindow ? DS.arena : DS.bg3).frame(width: 44, height: 26)
                    Circle().fill(.white).frame(width: 22, height: 22).padding(2)
                }
                .onTapGesture { withAnimation(reduceMotion ? nil : .spring()) { draft.challengesOutsideBetWindow.toggle() } }
                .accessibilityLabel("Arena duels")
                .accessibilityValue(draft.challengesOutsideBetWindow ? "activado" : "desactivado")
                .accessibilityAddTraits(.isButton)
            }
            .padding(16)
            .background(DS.arena.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                    .stroke(DS.arena.opacity(0.3), lineWidth: 1)
            )
            .padding(.top, 6)
        }
    }
}

// MARK: - Step 4: Economía

private struct CreateStep4Content: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @Binding var draft: LeagueCreateDraft
    private let balances = [1000, 5000, 10000]
    private let betLimits = [1, 2, 3, 99]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                DSEyebrow(text: appLang == .es ? "Saldo inicial (puntos)" : "Starting balance (points)")
                HStack(spacing: 8) {
                    ForEach(balances, id: \.self) { v in
                        let sel = v == draft.initialBalanceSelection
                        Button(action: { withAnimation(reduceMotion ? nil : .default) { draft.initialBalanceSelection = v } }) {
                            VStack(spacing: 4) {
                                Text(v.formatted(.number))
                                    .font(.jbMono(22, weight: .black))
                                    .foregroundStyle(sel ? DS.fg : DS.fg)
                                Text("pts")
                                    .font(.system(size: 11))
                                    .foregroundStyle(sel ? DS.fg3 : DS.fg3)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(sel ? DS.bg2 : DS.bg1)
                            .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                                    .stroke(sel ? DS.accent : DS.line, lineWidth: sel ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                DSEyebrow(text: appLang == .es ? "Apuestas / día activo" : "Bets / active day")
                HStack(spacing: 8) {
                    ForEach(betLimits, id: \.self) { v in
                        let sel = v == draft.betsPerActiveDaySelection
                        Button(action: { withAnimation(reduceMotion ? nil : .default) { draft.betsPerActiveDaySelection = v } }) {
                            Text(v >= 99 ? "∞" : "\(v)")
                                .font(.jbMono(24, weight: .black))
                                .foregroundStyle(DS.fg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(sel ? DS.bg2 : DS.bg1)
                                .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                                        .stroke(sel ? DS.accent : DS.line, lineWidth: sel ? 1.5 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Summary card
            VStack(alignment: .leading, spacing: 10) {
                DSEyebrow(text: appLang == .es ? "resumen" : "summary")
                let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let nameLabel = trimmedName.isEmpty ? (appLang == .es ? "Sin nombre" : "Unnamed") : trimmedName
                let windowLabel: String = {
                    switch draft.betWindowPreset {
                    case .daily:   return appLang == .es ? "Todos los días" : "Every day"
                    case .weekdays: return appLang == .es ? "Solo entre semana" : "Weekdays only"
                    case .weekend: return appLang == .es ? "Solo findes" : "Weekends only"
                    case .custom:  return appLang == .es ? "Días personalizados" : "Custom days"
                    }
                }()
                let arenaSuffix = draft.challengesOutsideBetWindow ? (appLang == .es ? " · Arena 1v1 libre" : " · Open 1v1 Arena") : ""
                let rows: [(String, String)] = [
                    (appLang == .es ? "Liga" : "League", nameLabel),
                    (appLang == .es ? "Deportes" : "Sports", draft.allowedCompetitions.map { $0.title(lang: appLang) }.joined(separator: ", ")),
                    (appLang == .es ? "Ventana" : "Window", windowLabel + arenaSuffix),
                    (appLang == .es ? "Economía" : "Economy", "\(draft.resolvedInitialBalance) pts \(appLang == .es ? "inicial" : "start") · \(draft.betsPerActiveDaySelection >= 99 ? "∞" : "\(draft.betsPerActiveDaySelection)") \(appLang == .es ? "bets/día" : "bets/day")"),
                ]
                VStack(spacing: 0) {
                    ForEach(rows, id: \.0) { k, v in
                        HStack {
                            Text(k)
                                .textCase(.uppercase)
                                .font(.jbMono(10, weight: .semibold))
                                .tracking(1.4)
                                .foregroundStyle(DS.fg3)
                            Spacer()
                            Text(v)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(DS.fg)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        if k != rows.last?.0 {
                            Divider().background(DS.line)
                        }
                    }
                }
                .dsCard()
            }

            Text(appLang == .es ? "Al confirmar serás el administrador de esta liga." : "When you confirm, you will be this league's admin.")
                .font(.system(size: 12))
                .foregroundStyle(DS.fg3)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - League Detail (ScreenLeagueDetail)

private struct LeagueDetailView: View {
    @EnvironmentObject var leagueService: LeagueService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @AppStorage("selectedLeagueId") private var selectedLeagueId = ""
    @AppStorage("profileAvatarImageData") private var legacyAvatarImageData: Data = Data()
    @AppStorage("betsyProfileAvatarStoreDataV1") private var profileAvatarStoreData: Data = Data()
    let onBack: () -> Void
    @State private var showCopiedToast = false
    @State private var showLeaveConfirm = false
    @State private var showEditSheet = false

    private var league: FriendLeague? {
        ActiveLeagueStore.resolve(from: leagueService.myLeagues, selectedId: selectedLeagueId)
    }
    private var members: [LeagueMember] {
        guard let l = league else { return [] }
        return (leagueService.membersByLeague[l.id] ?? []).sorted { $0.points > $1.points }
    }
    private var myUid: String? { leagueService.currentUserId }
    private var myMember: LeagueMember? {
        members.first(where: { $0.id == myUid })
    }
    private var myRank: Int? {
        members.firstIndex(where: { $0.id == myUid }).map { $0 + 1 }
    }

    private var isAdmin: Bool {
        guard let creator = league?.createdBy, !creator.isEmpty,
              let uid = leagueService.currentUserId else { return false }
        return creator == uid
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

    private func copyCode() {
        guard let league else { return }
        UIPasteboard.general.string = league.code
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(notification: .announcement, argument: "Código copiado")
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2)) { showCopiedToast = false }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 10)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.fg)
                        .dsBackButton()
                }
                .buttonStyle(.plain)
                Spacer()
                Text(league?.name.lowercased() ?? (appLang == .es ? "liga" : "league"))
                    .font(.jbMono(11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(DS.fg3)
                    .lineLimit(1)
                Spacer()
                Button(action: copyCode) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.fg)
                        .dsBackButton()
                }
                .buttonStyle(.plain)
                .disabled(league == nil)
                .accessibilityLabel(appLang == .es ? "Compartir código de liga" : "Share league code")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 0) {
                    // Hero
                    if let league {
                        ZStack(alignment: .topLeading) {
                            DSArenaGrid(opacity: 0.3)
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    DSPill(text: appLang == .es ? "SELECCIONADA" : "SELECTED", bg: DS.accentSoft,
                                           border: DS.accentLine, fg: DS.accent, fontSize: 11, dot: DS.accent)
                                    Spacer()
                                    Text(appLang == .es ? "\(league.members) jugadores" : "\(league.members) players")
                                        .font(.jbMono(10, weight: .semibold))
                                        .tracking(1.4)
                                        .foregroundStyle(DS.fg3)
                                }
                                Text(league.name)
                                    .font(.bebas(36))
                                    .tracking(-0.5)
                                    .foregroundStyle(DS.fg)
                                    .padding(.top, 14)
                                FlowLayout(spacing: 6) {
                                    ForEach(league.settings.allowedCompetitions, id: \.rawValue) { comp in
                                        DSPill(text: comp.title(lang: appLang), fontSize: 10)
                                    }
                                }
                                .padding(.top, 10)
                                HStack {
                                    LeagueStatCol(label: appLang == .es ? "tu pos." : "your pos.", value: myRank.map { "\($0)º" } ?? "—", accent: true)
                                    Spacer()
                                    LeagueStatCol(label: appLang == .es ? "balance" : "balance", value: myMember.map { "\($0.points)" } ?? "—", accent: false)
                                    Spacer()
                                    Button(action: copyCode) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Text(appLang == .es ? "CÓDIGO" : "CODE")
                                                    .font(.jbMono(11, weight: .semibold))
                                                    .tracking(1.4)
                                                    .foregroundStyle(DS.fg3)
                                                Image(systemName: "doc.on.doc")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(DS.accent)
                                            }
                                            Text(league.code)
                                                .font(.jbMono(26, weight: .black))
                                                .tracking(-0.3)
                                                .foregroundStyle(DS.fg)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, 18)
                            }
                            .padding(20)
                        }
                        .background(
                            LinearGradient(colors: [DS.bg2, DS.bg1],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                                .stroke(DS.line, lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 4)
                    }

                    // Leaderboard
                    DSSectionRow(title: appLang == .es ? "Clasificación completa" : "Full leaderboard")

                    VStack(spacing: 0) {
                        if members.isEmpty {
                            HStack {
                                ProgressView().tint(DS.accent).scaleEffect(0.8)
                                Text(appLang == .es ? "Cargando…" : "Loading…").font(.system(size: 13)).foregroundStyle(DS.fg3)
                            }
                            .padding(16)
                        } else {
                            ForEach(Array(members.enumerated()), id: \.offset) { idx, member in
                                LeaderboardRow(
                                    pos: idx + 1,
                                    member: member,
                                    isMe: member.id == myUid,
                                    avatarImageData: avatarImageData(for: member.id)
                                )
                                if idx < members.count - 1 {
                                    Divider().background(DS.line)
                                }
                            }
                        }
                    }
                    .background(DS.bg1)
                    .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                            .stroke(DS.line, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    // Rules
                    if let league {
                        DSSectionRow(title: appLang == .es ? "Reglas" : "Rules")
                        let rules: [(String, String)] = [
                            (appLang == .es ? "Saldo inicial" : "Starting balance", "\(league.settings.initialBalance) pts"),
                            (appLang == .es ? "Bets / día" : "Bets / day", "\(league.settings.betsPerActiveDay) \(appLang == .es ? "máx" : "max")"),
                            (appLang == .es ? "Ventana" : "Window", league.settings.betWindowPreset.title(lang: appLang)),
                            (appLang == .es ? "Arena fuera ventana" : "Arena outside window", league.settings.challengesOutsideBetWindow ? (appLang == .es ? "Permitido" : "Allowed") : "No"),
                            (appLang == .es ? "Visibilidad" : "Visibility", league.settings.visibility.title(lang: appLang)),
                        ]
                        VStack(spacing: 0) {
                            ForEach(rules, id: \.0) { k, v in
                                HStack {
                                    Text(k)
                                        .textCase(.uppercase)
                                        .font(.jbMono(10, weight: .semibold))
                                        .tracking(1.4)
                                        .foregroundStyle(DS.fg3)
                                    Spacer()
                                    Text(v)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(DS.fg)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                if k != rules.last?.0 {
                                    Divider().background(DS.line)
                                }
                            }
                        }
                        .dsCard()
                        .padding(.horizontal, 20)

                        if isAdmin {
                            Button(action: { showEditSheet = true }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(appLang == .es ? "Editar ajustes de la liga" : "Edit league settings")
                                        .font(.system(size: 14, weight: .bold))
                                    Spacer()
                                    DSPill(text: "ADMIN", bg: DS.accentSoft, border: DS.accentLine, fg: DS.accent, fontSize: 9)
                                }
                                .foregroundStyle(DS.fg)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(DS.bg1)
                                .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                                    .stroke(DS.accentLine, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .accessibilityLabel(appLang == .es ? "Editar ajustes de la liga" : "Edit league settings")
                        }

                        // Leave league action
                        Button(action: { showLeaveConfirm = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(appLang == .es ? "Salir de la liga" : "Leave league")
                                    .font(.system(size: 14, weight: .bold))
                                Spacer()
                            }
                            .foregroundStyle(DS.loss)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(DS.loss.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                                .stroke(DS.loss.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .background(DS.bg.ignoresSafeArea())
        .alert(appLang == .es ? "¿Salir de la liga?" : "Leave league?", isPresented: $showLeaveConfirm) {
            Button(appLang == .es ? "Salir" : "Leave", role: .destructive) {
                guard let league else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                leagueService.leaveLeague(leagueId: league.id)
                if selectedLeagueId == league.id { selectedLeagueId = "" }
                onBack()
            }
            Button(appLang == .es ? "Cancelar" : "Cancel", role: .cancel) {}
        } message: {
            Text(appLang == .es
                 ? "Perderás tu posición y balance en esta liga. Si eres el último miembro, la liga se borrará."
                 : "You will lose your position and balance in this league. If you are the last member, the league will be deleted.")
        }
        .sheet(isPresented: $showEditSheet) {
            if let league {
                EditLeagueSheet(league: league, isPresented: $showEditSheet)
                    .environmentObject(leagueService)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                Text(appLang == .es ? "Código copiado" : "Code copied")
                    .font(.jbMono(11, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(DS.accentInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(DS.accent)
                    .clipShape(Capsule())
                    .shadow(color: DS.accent.opacity(0.4), radius: 12)
                    .padding(.top, 70)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            if let league { leagueService.loadMembers(for: league) }
        }
    }
}

// MARK: - Leaderboard row (real data version)

private struct LeaderboardRow: View {
    let pos: Int
    let member: LeagueMember
    let isMe: Bool
    let avatarImageData: Data?
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    private var deltaSign: String { member.pointsToday >= 0 ? "+" : "" }
    private var deltaColor: Color { member.pointsToday >= 0 ? DS.win : DS.loss }

    private var podiumColor: Color? {
        switch pos {
        case 1: return Color(dsHex: "f5c542") // gold
        case 2: return Color(dsHex: "c0c0c0") // silver
        case 3: return Color(dsHex: "cd7f32") // bronze
        default: return nil
        }
    }

    @ViewBuilder
    private var positionMarker: some View {
        if let podium = podiumColor {
            ZStack {
                Circle()
                    .fill(podium.opacity(0.18))
                    .overlay(Circle().stroke(podium.opacity(0.55), lineWidth: 1))
                Text("\(pos)")
                    .font(.jbMono(13, weight: .black))
                    .foregroundStyle(podium)
            }
            .frame(width: 26, height: 26)
        } else {
            Text("\(pos)")
                .font(.jbMono(18, weight: .black))
                .foregroundStyle(DS.fg3)
                .frame(width: 26, alignment: .center)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            positionMarker
            DSAvatar(name: member.name, size: 30, accent: isMe, imageData: avatarImageData)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.fg)
                if isMe {
                    Text(appLang == .es ? "Tú" : "You")
                        .font(.jbMono(11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(DS.accent)
                } else if pos == 1 {
                    Text(appLang == .es ? "LÍDER" : "LEADER")
                        .font(.jbMono(11, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(podiumColor ?? DS.fg3)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(member.points)")
                    .font(.jbMono(16, weight: .black))
                    .foregroundStyle(DS.fg)
                Text("\(deltaSign)\(member.pointsToday)")
                    .font(.jbMono(10, weight: .semibold))
                    .foregroundStyle(deltaColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isMe ? DS.accentSoft : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }

    private var a11yLabel: String {
        var parts: [String] = []
        parts.append(appLang == .es ? "Posición \(pos)" : "Position \(pos)")
        parts.append(member.name)
        parts.append(appLang == .es ? "\(member.points) puntos" : "\(member.points) points")
        let delta = member.pointsToday
        if delta != 0 {
            parts.append(delta > 0
                         ? (appLang == .es ? "subiendo \(delta)" : "up \(delta)")
                         : (appLang == .es ? "bajando \(-delta)" : "down \(-delta)"))
        }
        if isMe { parts.append(appLang == .es ? "tú" : "you") }
        else if pos == 1 { parts.append(appLang == .es ? "líder" : "leader") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Edit League sheet (admin only)

private struct EditLeagueSheet: View {
    let league: FriendLeague
    @Binding var isPresented: Bool
    @EnvironmentObject var leagueService: LeagueService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es

    @State private var name: String
    @State private var allowedCompetitions: Set<LeagueCompetition>
    @State private var betWindowPreset: LeagueBetWindowPreset
    @State private var challengesOutsideBetWindow: Bool
    @State private var betsPerActiveDay: Int
    @State private var saving = false
    @State private var showSavedToast = false

    private let competitions: [(LeagueCompetition, String)] = [
        (.nba, "🏀"), (.laLiga, "⚽"), (.premier, "⚽"),
        (.bundesliga, "⚽"), (.serieA, "⚽"), (.ligue1, "⚽"),
    ]
    private var windows: [(LeagueBetWindowPreset, String, String)] {
        if appLang == .es {
            return [
                (.daily, "Todos los días", "L M X J V S D"),
                (.weekdays, "Solo entre semana", "L M X J V"),
                (.weekend, "Solo fines de semana", "S D"),
            ]
        }
        return [
            (.daily, "Every day", "M T W T F S S"),
            (.weekdays, "Weekdays only", "M T W T F"),
            (.weekend, "Weekends only", "S S"),
        ]
    }
    private let limits = [1, 2, 3, 99]

    init(league: FriendLeague, isPresented: Binding<Bool>) {
        self.league = league
        self._isPresented = isPresented
        _name = State(initialValue: league.name)
        _allowedCompetitions = State(initialValue: Set(league.settings.allowedCompetitions))
        _betWindowPreset = State(initialValue: league.settings.betWindowPreset == .custom ? .daily : league.settings.betWindowPreset)
        _challengesOutsideBetWindow = State(initialValue: league.settings.challengesOutsideBetWindow)
        _betsPerActiveDay = State(initialValue: max(league.settings.betsPerActiveDay, 1))
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var hasChanges: Bool {
        trimmedName != league.name
            || Set(league.settings.allowedCompetitions) != allowedCompetitions
            || league.settings.betWindowPreset != betWindowPreset
            || league.settings.challengesOutsideBetWindow != challengesOutsideBetWindow
            || league.settings.betsPerActiveDay != betsPerActiveDay
    }
    private var canSave: Bool {
        !trimmedName.isEmpty && !allowedCompetitions.isEmpty && betsPerActiveDay > 0 && hasChanges && !saving
    }

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        nameSection
                        competitionsSection
                        windowSection
                        arenaToggle
                        limitsSection
                        Text(appLang == .es
                             ? "Saldo inicial y código de la liga no se pueden modificar tras la creación."
                             : "Starting balance and league code cannot be changed after creation.")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.fg3)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
            }
            VStack {
                Spacer()
                DSButton(
                    title: saving
                        ? (appLang == .es ? "Guardando…" : "Saving…")
                        : (appLang == .es ? "Guardar cambios" : "Save changes"),
                    style: .primary,
                    fullWidth: true,
                    height: 54,
                    action: save
                )
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(DS.bg1)
                .overlay(Rectangle().fill(DS.line).frame(height: 1), alignment: .top)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            if showSavedToast {
                Text(appLang == .es ? "Ajustes guardados" : "Settings saved")
                    .font(.jbMono(11, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(DS.accentInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(DS.accent)
                    .clipShape(Capsule())
                    .shadow(color: DS.accent.opacity(0.35), radius: 14)
                    .padding(.top, 62)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: showSavedToast)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(appLang == .es ? "ADMIN · LIGA" : "ADMIN · LEAGUE")
                    .font(.jbMono(10, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(DS.accent)
                Text(appLang == .es ? "Editar ajustes" : "Edit settings")
                    .font(.bebas(34))
                    .tracking(-0.5)
                    .foregroundStyle(DS.fg)
            }
            Spacer()
            Button { isPresented = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(DS.fg)
                    .frame(width: 36, height: 36)
                    .background(DS.bg2)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(DS.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appLang == .es ? "Cerrar" : "Close")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSEyebrow(text: appLang == .es ? "Nombre de la liga" : "League name")
            TextField("", text: $name)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(DS.fg)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(DS.bg1)
                .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                        .stroke(DS.line, lineWidth: 1)
                )
        }
    }

    private var competitionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSEyebrow(text: appLang == .es ? "Deportes permitidos" : "Allowed sports")
            VStack(spacing: 6) {
                ForEach(competitions, id: \.0) { competition, emoji in
                    let sel = allowedCompetitions.contains(competition)
                    Button {
                        if sel, allowedCompetitions.count > 1 {
                            allowedCompetitions.remove(competition)
                        } else {
                            allowedCompetitions.insert(competition)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(emoji).font(.system(size: 16))
                            Text(competition.title(lang: appLang))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(DS.fg)
                            Spacer()
                            Image(systemName: sel ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16))
                                .foregroundStyle(sel ? DS.accent : DS.fg3)
                        }
                        .padding(12)
                        .background(sel ? DS.accentSoft : DS.bg1)
                        .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                            .stroke(sel ? DS.accentLine : DS.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var windowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSEyebrow(text: appLang == .es ? "Ventana de juego" : "Game window")
            VStack(spacing: 6) {
                ForEach(windows, id: \.0) { item in
                    let sel = item.0 == betWindowPreset
                    Button { betWindowPreset = item.0 } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.1).font(.system(size: 14, weight: .bold)).foregroundStyle(DS.fg)
                                Text(item.2).font(.system(size: 11)).foregroundStyle(DS.fg3)
                            }
                            Spacer()
                            ZStack {
                                Circle().stroke(sel ? DS.accent : DS.line2, lineWidth: 1.5).frame(width: 22, height: 22)
                                if sel { Circle().fill(DS.accent).frame(width: 12, height: 12) }
                            }
                        }
                        .padding(14)
                        .background(sel ? DS.accentSoft : DS.bg1)
                        .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                            .stroke(sel ? DS.accentLine : DS.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var arenaToggle: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appLang == .es ? "Arena fuera de ventana" : "Arena outside window")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DS.fg)
                Text(appLang == .es ? "Permitir retos 1v1 cualquier día" : "Allow 1v1 challenges any day")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.fg3)
            }
            Spacer()
            ZStack(alignment: challengesOutsideBetWindow ? .trailing : .leading) {
                Capsule().fill(challengesOutsideBetWindow ? DS.arena : DS.bg3).frame(width: 44, height: 26)
                Circle().fill(.white).frame(width: 22, height: 22).padding(2)
            }
            .onTapGesture { withAnimation(reduceMotion ? nil : .spring()) { challengesOutsideBetWindow.toggle() } }
            .accessibilityLabel("Arena duels")
            .accessibilityValue(challengesOutsideBetWindow ? "activado" : "desactivado")
            .accessibilityAddTraits(.isButton)
        }
        .padding(14)
        .background(DS.bg1)
        .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous).stroke(DS.line, lineWidth: 1))
    }

    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSEyebrow(text: appLang == .es ? "Apuestas por día" : "Bets per day")
            HStack(spacing: 6) {
                ForEach(limits, id: \.self) { v in
                    let sel = v == betsPerActiveDay
                    Button { betsPerActiveDay = v } label: {
                        Text(v >= 99 ? "∞" : "\(v)")
                            .font(.jbMono(20, weight: .black))
                            .foregroundStyle(sel ? DS.accentInk : DS.fg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(sel ? DS.accent : DS.bg1)
                            .clipShape(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: DS.rMd, style: .continuous)
                                .stroke(sel ? DS.accent : DS.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        saving = true
        var newSettings = league.settings
        newSettings.allowedCompetitions = Array(allowedCompetitions).sorted { $0.rawValue < $1.rawValue }
        newSettings.betWindowPreset = betWindowPreset
        newSettings.activeWeekdays = []
        newSettings.challengesOutsideBetWindow = challengesOutsideBetWindow
        newSettings.betsPerActiveDay = betsPerActiveDay
        let request = LeagueCreateRequest(name: trimmedName, settings: newSettings)
        leagueService.updateLeague(leagueId: league.id, request: request) { ok in
            saving = false
            if ok {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                UIAccessibility.post(notification: .announcement, argument: appLang == .es ? "Ajustes guardados" : "Settings saved")
                showSavedToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    isPresented = false
                }
            }
        }
    }
}
