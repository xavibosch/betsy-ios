import SwiftUI

struct ArenaView: View {
    let duel: ArenaDuel
    @ObservedObject var leagueService: LeagueService
    let lang: AppLang
    var currentUserAvatarImageData: Data? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var selections: [ArenaBetSelection] = []
    @State private var error: String? = nil

    // The current immediate Arena flow assigns a focused match, so one locked pick is enough.
    private let minPicks = 1
    private let maxPicks = 3

    private var liveDuel: ArenaDuel {
        leagueService.activeArena ?? duel
    }

    private var isSubmitted: Bool {
        guard let uid = leagueService.currentUserId else { return false }
        if uid == liveDuel.challengerId {
            return !liveDuel.challengerSelections.isEmpty
        }
        if uid == liveDuel.opponentId {
            return !liveDuel.opponentSelections.isEmpty
        }
        return false
    }

    private var currentSelections: [ArenaBetSelection] {
        guard let uid = leagueService.currentUserId else { return [] }
        if uid == liveDuel.challengerId {
            return liveDuel.challengerSelections
        }
        if uid == liveDuel.opponentId {
            return liveDuel.opponentSelections
        }
        return []
    }

    private var canBet: Bool {
        if liveDuel.status == "active" { return true }
        guard let uid = leagueService.currentUserId else { return false }
        return uid == liveDuel.opponentId && liveDuel.status == "pending"
    }

    private var displayedSelections: [ArenaBetSelection] {
        selections.isEmpty ? currentSelections : selections
    }

    private var arenaState: ArenaChallengeState {
        switch liveDuel.status {
        case "pending":
            return .pending
        case "active":
            return .active
        case "resolved":
            return .resolved
        case "declined":
            return .rejected
        default:
            return .active
        }
    }

    private var duelStatusTitle: String {
        switch liveDuel.status {
        case "pending":
            return arenaState.label(lang: lang)
        case "active":
            return isSubmitted
                ? (lang == .es ? "Tu pick está enviado" : "Your pick is locked")
                : (lang == .es ? "Elige tu selección" : "Choose your selection")
        case "resolved":
            return arenaState.label(lang: lang)
        default:
            return lang == .es ? "Arena" : "Arena"
        }
    }

    private var duelStatusMessage: String {
        if liveDuel.status == "pending" && liveDuel.challengerId == leagueService.currentUserId {
            return lang == .es
                ? "El rival debe aceptar antes de que el duelo quede activo."
                : "Your opponent must accept before the duel becomes active."
        }
        if liveDuel.status == "active" && isSubmitted {
            return lang == .es
                ? "Tu selección ya está guardada. Espera a que el rival envíe la suya o al resultado final."
                : "Your selection is already saved. Wait for your rival pick or for the final result."
        }
        if liveDuel.status == "active" {
            return lang == .es
                ? "Elige entre \(minPicks) y \(maxPicks) picks. Los puntos ya están en juego; aquí solo eliges los resultados."
                : "Pick between \(minPicks) and \(maxPicks) outcomes. Points are already staked — here you only choose the results."
        }
        return lang == .es ? "Sigue el estado del duelo desde esta pantalla." : "Track the duel state from this screen."
    }

    private var picksRemainingText: String {
        let count = displayedSelections.count
        if count < minPicks {
            return lang == .es
                ? "Te faltan \(minPicks - count) pick(s)."
                : "You need \(minPicks - count) more pick(s)."
        }
        if count > maxPicks {
            return lang == .es
                ? "Tienes demasiados picks. Quita \(count - maxPicks)."
                : "Too many picks. Remove \(count - maxPicks)."
        }
        return lang == .es
            ? "\(count)/\(maxPicks) picks listos."
            : "\(count)/\(maxPicks) picks ready."
    }

    private var challengeMatch: ArenaMatch? {
        liveDuel.matches.first
    }

    private func arenaAvatarData(for userId: String) -> Data? {
        guard userId == leagueService.currentUserId else { return nil }
        return currentUserAvatarImageData
    }

    private func duelDisplayName(userId: String, fallback: String) -> String {
        userId == leagueService.currentUserId ? (lang == .es ? "Tú" : "You") : fallback
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        BetsyScreenHeader(
                            eyebrow: lang == .es ? "Arena 1v1" : "Arena 1v1",
                            title: "\(liveDuel.challengerName) vs \(liveDuel.opponentName)",
                            subtitle: duelStatusMessage,
                            tone: .dark
                        )

                        BetsyCard(tone: .dark, backgroundColor: Theme.surface, padding: 14, radius: 18, borderColor: Theme.hot.opacity(0.24)) {
                            HStack(spacing: 10) {
                                ArenaStateBadgeView(state: arenaState, lang: lang)
                                arenaStatePill(title: isSubmitted ? (lang == .es ? "Tu pick enviado" : "Your pick sent") : (lang == .es ? "Pick pendiente" : "Pick pending"))
                                if liveDuel.status == "resolved" {
                                    arenaStatePill(title: lang == .es ? "Liquidado" : "Settled")
                                }
                            }
                        }

                        BetsyCard(tone: .dark, backgroundColor: Theme.surface, padding: 18, radius: 22, borderColor: Theme.hot.opacity(0.20)) {
                            HStack(spacing: 10) {
                                BetsyAvatarView(
                                    imageData: arenaAvatarData(for: liveDuel.challengerId),
                                    name: liveDuel.challengerName,
                                    size: 46,
                                    borderColor: Theme.hot.opacity(0.35),
                                    fillColor: Color.white.opacity(0.08),
                                    textColor: Theme.ink
                                )
                                Text(duelDisplayName(userId: liveDuel.challengerId, fallback: liveDuel.challengerName))
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Spacer()
                                Text("VS")
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundStyle(Theme.hot)
                                    .accessibilityHidden(true)
                                Spacer()
                                Text(duelDisplayName(userId: liveDuel.opponentId, fallback: liveDuel.opponentName))
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                BetsyAvatarView(
                                    imageData: arenaAvatarData(for: liveDuel.opponentId),
                                    name: liveDuel.opponentName,
                                    size: 46,
                                    borderColor: Theme.hot.opacity(0.35),
                                    fillColor: Color.white.opacity(0.08),
                                    textColor: Theme.ink
                                )
                            }

                            HStack(spacing: 12) {
                                arenaMetricBlock(
                                    title: lang == .es ? "Apuesta" : "Stake",
                                    value: "\(liveDuel.wager) pts"
                                )

                                arenaMetricBlock(
                                    title: lang == .es ? "Estado" : "Status",
                                    value: duelStatusTitle
                                )
                            }

                            if !liveDuel.matches.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(lang == .es ? "PARTIDOS DEL DUELO" : "DUEL MATCHES")
                                        .font(.system(size: 11, weight: .black))
                                        .tracking(0.8)
                                        .foregroundStyle(Theme.inkTertiary)

                                    Text(
                                        lang == .es
                                            ? "\(liveDuel.matches.count) partidos aleatorios"
                                            : "\(liveDuel.matches.count) random matches"
                                    )
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundStyle(Theme.ink)

                                    Text(
                                        liveDuel.matches
                                            .map { $0.league }
                                            .reduce(into: [String]()) { partial, league in
                                                if !partial.contains(league) { partial.append(league) }
                                            }
                                            .joined(separator: " · ")
                                    )
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.inkSecondary)
                                    .lineLimit(2)
                                }
                            }
                        }

                        if let error = error {
                            BetsyErrorStateView(
                                title: lang == .es ? "No se pudo guardar la apuesta" : "Unable to save bet",
                                message: error
                            )
                        }

                        ForEach(liveDuel.matches) { match in
                            ArenaMatchRow(
                                match: match,
                                selections: $selections,
                                isLocked: isSubmitted || !canBet,
                                lang: lang
                            )
                        }

                        if !displayedSelections.isEmpty || canBet {
                            BetsyCard(tone: .dark, backgroundColor: Theme.surface, padding: 16, radius: 18, borderColor: Theme.border) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(lang == .es ? "Tus picks" : "Your picks")
                                            .font(.system(size: 18, weight: .black))
                                            .foregroundStyle(Theme.ink)
                                        Spacer()
                                        Text("\(displayedSelections.count)/\(maxPicks)")
                                            .font(.system(size: 13, weight: .black))
                                            .foregroundStyle(Theme.bg)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Theme.accent)
                                    }

                                    if canBet && !isSubmitted {
                                        Text(picksRemainingText)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(
                                                displayedSelections.count < minPicks || displayedSelections.count > maxPicks
                                                    ? Color(red: 0.86, green: 0.19, blue: 0.19)
                                                    : Theme.inkSecondary
                                            )
                                    }

                                    if displayedSelections.isEmpty {
                                        Text(lang == .es ? "Aún no has elegido picks." : "You have not chosen picks yet.")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Theme.inkSecondary)
                                    } else {
                                        ForEach(displayedSelections) { selection in
                                            Text(selectionSummary(selection))
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(Theme.ink)
                                        }
                                    }
                                }
                            }
                        }

                        let validCount = selections.count >= minPicks && selections.count <= maxPicks
                        let canConfirm = validCount && !isSubmitted && canBet
                        BetsyButton(
                            title: isSubmitted
                                ? (lang == .es ? "Picks guardados" : "Picks saved")
                                : (lang == .es ? "Guardar picks" : "Save picks"),
                            style: .primary,
                            isDisabled: !canConfirm
                        ) {
                            guard selections.count >= minPicks else {
                                error = lang == .es
                                    ? "Debes elegir al menos \(minPicks) picks."
                                    : "Pick at least \(minPicks) outcomes."
                                return
                            }
                            guard selections.count <= maxPicks else {
                                error = lang == .es
                                    ? "Solo puedes enviar hasta \(maxPicks) picks."
                                    : "You can only send up to \(maxPicks) picks."
                                return
                            }
                            leagueService.submitArenaSelection(duel: liveDuel, selections: selections)
                            error = nil
                            dismiss()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .onAppear {
                selections = currentSelections
                triggerAutoResolveIfReady()
            }
            .onReceive(leagueService.$activeArena) { _ in
                selections = currentSelections
                triggerAutoResolveIfReady()
            }
            .navigationTitle(lang == .es ? "Arena" : "Arena")
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

    /// Triggers random resolution of the duel if both players have submitted
    /// their picks and the duel is still in "active" state.
    /// Fires after an 8-second delay so users can see the "picks locked" state.
    private func triggerAutoResolveIfReady() {
        guard liveDuel.status == "active",
              !liveDuel.challengerSelections.isEmpty,
              !liveDuel.opponentSelections.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            guard leagueService.activeArena?.status == "active" else { return }
            leagueService.resolveArenaDuelsRandomly(leagueId: liveDuel.leagueId)
        }
    }

    private func arenaStatePill(title: String) -> some View {
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

    private func arenaMetricBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).textCase(.uppercase)
                .font(.system(size: 11, weight: .black))
                .tracking(0.8)
                .foregroundStyle(Theme.inkTertiary)
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func selectionSummary(_ selection: ArenaBetSelection) -> String {
        let label = readableOddLabel(
            selection.oddLabel,
            home: selection.home,
            away: selection.away,
            lang: lang
        )
        return "\(selection.home) vs \(selection.away) · \(label) @ x\(String(format: "%.2f", selection.oddValue))"
    }
}
