import SwiftUI
import UIKit

struct ArenaChallengePickView: View {
    let challenge: ChallengeDraft
    let matches: [ArenaMatch]
    let lang: AppLang
    var currentUserAvatarImageData: Data? = nil
    @Binding var selections: [ArenaBetSelection]
    let errorMessage: String?
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Challenge rules
    private let minPicks = 2
    private let maxPicks = 3

    // Slide state
    @State private var step: Int = 0   // 0: intro · 1: pick outcomes · 2: summary
    private let slideCount = 3

    // MARK: Derived

    private var accent: Color { Theme.hot }

    private var canAdvance: Bool {
        switch step {
        case 0: return !matches.isEmpty
        case 1: return selections.count >= minPicks && selections.count <= maxPicks
        case 2: return selections.count >= minPicks && selections.count <= maxPicks
        default: return false
        }
    }

    private var continueTitle: String {
        switch step {
        case 0: return lang == .es ? "Ver partidos" : "See matches"
        case 1: return lang == .es ? "Ver resumen" : "See summary"
        case 2: return lang == .es ? "Enviar reto" : "Send challenge"
        default: return ""
        }
    }

    private var remainingPicksText: String {
        let count = selections.count
        if count < minPicks {
            return lang == .es
                ? "Te faltan \(minPicks - count) pick(s) para completar el reto."
                : "You need \(minPicks - count) more pick(s) to complete the challenge."
        }
        if count > maxPicks {
            return lang == .es
                ? "Has superado el máximo de \(maxPicks) picks. Quita alguno."
                : "You went over the \(maxPicks) max picks. Remove one."
        }
        return lang == .es
            ? "\(count) de \(maxPicks) picks elegidos. Listo para enviar."
            : "\(count) of \(maxPicks) picks chosen. Ready to send."
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 14) {
            stepperBar

            TabView(selection: $step) {
                introSlide
                    .tag(0)
                    .padding(.horizontal, 2)

                pickSlide
                    .tag(1)
                    .padding(.horizontal, 2)

                summarySlide
                    .tag(2)
                    .padding(.horizontal, 2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(minHeight: 560)
            .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.84), value: step)

            controlBar
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(red: 1.00, green: 0.96, blue: 0.93), Color(red: 0.96, green: 0.93, blue: 1.00)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: accent.opacity(0.22), radius: 24, x: 0, y: 12)
    }

    // MARK: Stepper

    private var stepperBar: some View {
        HStack(spacing: 10) {
            ForEach(0..<slideCount, id: \.self) { index in
                let isDone = index < step
                let isCurrent = index == step
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(
                                isDone ? AnyShapeStyle(Theme.winGradient)
                                : isCurrent ? AnyShapeStyle(Theme.arenaGradient)
                                : AnyShapeStyle(Color.white)
                            )
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .stroke(isCurrent || isDone ? Color.clear : Theme.bg.opacity(0.34), lineWidth: 1.5)
                            )
                            .shadow(color: (isCurrent ? accent : isDone ? Theme.lime : Color.clear).opacity(0.45), radius: 6, x: 0, y: 3)

                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Color.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(isCurrent ? Color.white : Theme.bg.opacity(0.65))
                        }
                    }
                    if index < slideCount - 1 {
                        Capsule()
                            .fill(isDone ? Theme.lime.opacity(0.5) : Theme.bg.opacity(0.10))
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
    }

    // MARK: Slides

    private var introSlide: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                heroChallengeCard
                assignedMatchesPreviewCard
                rulesCard
            }
            .padding(.bottom, 8)
        }
    }

    private var pickSlide: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                pickHeaderCard

                if let errorMessage, !errorMessage.isEmpty {
                    BetsyErrorStateView(
                        title: lang == .es ? "No se pudo preparar el reto" : "Unable to prepare the challenge",
                        message: errorMessage
                    )
                }

                if matches.isEmpty {
                    BetsyEmptyStateView(
                        title: lang == .es ? "Arena no pudo asignar partidos" : "Arena could not assign matches",
                        message: lang == .es
                            ? "No hay partidos futuros válidos para este reto ahora mismo. Cancela y vuelve a intentarlo más tarde."
                            : "There are no valid upcoming matches for this challenge right now. Cancel and try again later.",
                        systemImage: "sportscourt"
                    )
                } else {
                    ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                        ArenaMatchRow(
                            match: match,
                            selections: $selections,
                            isLocked: false,
                            lang: lang,
                            accent: rotatingAccent(for: index)
                        )
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }

    private var summarySlide: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                summaryHeroCard
                summaryPicksCard
                summaryDisclaimer
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: Hero (intro)

    private var heroChallengeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(lang == .es ? "PASO 1 · EL RETO" : "STEP 1 · THE DUEL")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(Color.white.opacity(0.82))
                Spacer()
                Text("1v1")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.hot)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .clipShape(Capsule())
            }

            HStack(alignment: .center, spacing: 14) {
                BetsyAvatarView(
                    imageData: currentUserAvatarImageData,
                    name: lang == .es ? "Tú" : "You",
                    size: 48,
                    borderColor: Color.white,
                    fillColor: Color.white.opacity(0.24),
                    textColor: Color.white
                )

                Text("VS")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.90))

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.24))
                        .frame(width: 48, height: 48)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    Text(challenge.opponentName.prefix(1).uppercased())
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(Color.white)
                }
                .accessibilityHidden(true)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.opponentName)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Color.white)
                Text(lang == .es ? "te espera en Arena." : "is waiting in the Arena.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.84))
            }

            HStack(spacing: 10) {
                heroStatPill(
                    title: lang == .es ? "APUESTA" : "WAGER",
                    value: "\(challenge.wager)",
                    unit: "pts"
                )
                heroStatPill(
                    title: lang == .es ? "RIESGO" : "AT RISK",
                    value: "\(challenge.wager)",
                    unit: "pts"
                )
                heroStatPill(
                    title: lang == .es ? "PICKS" : "PICKS",
                    value: "2–3",
                    unit: ""
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.arenaGradient)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Theme.hot.opacity(0.36), radius: 18, x: 0, y: 10)
    }

    private func heroStatPill(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .black))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.72))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.16))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.30), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var assignedMatchesPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.white)
                    .frame(width: 28, height: 28)
                    .background(Theme.heroGradient)
                    .clipShape(Circle())
                Text(lang == .es ? "Partidos aleatorios" : "Random matches")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.bg)
                Spacer()
                Text("\(matches.count)")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.electric)
                    .clipShape(Capsule())
            }

            if matches.isEmpty {
                Text(lang == .es ? "Todavía no hay partidos asignados." : "No matches assigned yet.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.bg.opacity(0.58))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                        HStack(alignment: .center, spacing: 10) {
                            Circle()
                                .fill(rotatingAccent(for: index))
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(match.home) vs \(match.away)")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(Theme.bg)
                                    .lineLimit(1)
                                Text(match.league)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.bg.opacity(0.52))
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.electric.opacity(0.28), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.white)
                    .frame(width: 26, height: 26)
                    .background(Theme.sunGradient)
                    .clipShape(Circle())
                Text(lang == .es ? "Reglas rápidas" : "Quick rules")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.bg)
            }
            ruleLine(
                icon: "target",
                color: Theme.hot,
                text: lang == .es
                    ? "Elige 2 o 3 resultados. El que acierte más, gana."
                    : "Pick 2 or 3 outcomes. Whoever hits more, wins."
            )
            ruleLine(
                icon: "flame.fill",
                color: Theme.electric,
                text: lang == .es
                    ? "Los puntos ya están apostados — solo eliges los picks."
                    : "Points are already staked — you only choose the picks."
            )
            ruleLine(
                icon: "trophy.fill",
                color: Theme.lime,
                text: lang == .es
                    ? "Si ganas, cobras la apuesta multiplicada por la cuota total de tus picks."
                    : "If you win, you receive the stake multiplied by the total odds of your picks."
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.sun.opacity(0.40), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func ruleLine(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color.white)
                .frame(width: 22, height: 22)
                .background(color)
                .clipShape(Circle())
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.bg.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Pick slide header

    private var pickHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(lang == .es ? "PASO 2 · TUS PICKS" : "STEP 2 · YOUR PICKS")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(Color.white.opacity(0.82))
                Spacer()
                Text("\(selections.count)/\(maxPicks)")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.electric)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white)
                    .clipShape(Capsule())
            }

            Text(lang == .es ? "Elige 2 o 3 resultados" : "Pick 2 or 3 outcomes")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color.white)

            Text(remainingPicksText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Theme.electric.opacity(0.32), radius: 14, x: 0, y: 6)
    }

    // MARK: Summary

    private var summaryHeroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang == .es ? "PASO 3 · CONFIRMAR" : "STEP 3 · CONFIRM")
                .font(.system(size: 11, weight: .black))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.82))

            Text(lang == .es ? "Todo listo para enviar" : "All set to send")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Color.white)

            HStack(spacing: 10) {
                summaryStat(
                    title: lang == .es ? "RIVAL" : "RIVAL",
                    value: challenge.opponentName
                )
                summaryStat(
                    title: lang == .es ? "PICKS" : "PICKS",
                    value: "\(selections.count)"
                )
                summaryStat(
                    title: lang == .es ? "APUESTA" : "STAKE",
                    value: "\(challenge.wager) pts"
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.winGradient)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Theme.lime.opacity(0.32), radius: 18, x: 0, y: 10)
    }

    private func summaryStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .black))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.76))
            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var summaryPicksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang == .es ? "Tus picks" : "Your picks")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.bg)

            if selections.isEmpty {
                Text(lang == .es ? "Aún no has elegido picks." : "You have not chosen any picks yet.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.bg.opacity(0.58))
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(selections.enumerated()), id: \.element.id) { index, selection in
                        if let match = matches.first(where: { $0.id == selection.matchId }) {
                            summaryPickRow(
                                match: match,
                                selection: selection,
                                accent: rotatingAccent(for: index)
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.lime.opacity(0.36), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func summaryPickRow(match: ArenaMatch, selection: ArenaBetSelection, accent: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(match.home) vs \(match.away)")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.bg)
                Text(
                    readableOddLabel(
                        selection.oddLabel,
                        home: selection.home,
                        away: selection.away,
                        lang: lang
                    )
                    + " @ x\(String(format: "%.2f", selection.oddValue))"
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.bg.opacity(0.64))
            }
            Spacer()
        }
        .padding(10)
        .background(accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var summaryDisclaimer: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Theme.bg.opacity(0.68))
                .accessibilityHidden(true)
            Text(lang == .es
                ? "Cuando envíes el reto, tu rival recibirá un splash de Arena."
                : "When you send it, your rival gets an Arena splash.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.bg.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Controls

    private var controlBar: some View {
        HStack(spacing: 10) {
            if step == 0 {
                BetsyButton(
                    title: lang == .es ? "Cancelar" : "Cancel",
                    style: .secondary,
                    fillsWidth: false
                ) {
                    onCancel()
                }
            } else {
                BetsyButton(
                    title: lang == .es ? "Atrás" : "Back",
                    systemImage: "chevron.left",
                    style: .secondary,
                    fillsWidth: false
                ) {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.82)) {
                        step = max(step - 1, 0)
                    }
                }
            }

            BetsyButton(
                title: continueTitle,
                systemImage: step == 2 ? "bolt.fill" : "chevron.right",
                style: step == 2 ? .arena : .hero,
                isDisabled: !canAdvance
            ) {
                if step == 2 {
                    onConfirm()
                } else {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.82)) {
                        step = min(step + 1, slideCount - 1)
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func rotatingAccent(for index: Int) -> Color {
        let palette: [Color] = [Theme.hot, Theme.electric, Theme.sun, Theme.lime, Theme.violetPop, Theme.skyPop]
        return palette[index % palette.count]
    }
}
