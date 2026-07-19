import SwiftUI

// MARK: - Play Tutorial Overlay
// First-time contextual tour of the Play tab.
// First-time display is controlled by BetsyPlayScreen so it can be scoped per user.

enum PlayTutorialTarget: Hashable {
    case betsTab
    case filters
    case firstMatch
    case ticketTray
    case arenaTab
}

struct PlayTutorialTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [PlayTutorialTarget: Anchor<CGRect>] = [:]

    static func reduce(value: inout [PlayTutorialTarget: Anchor<CGRect>], nextValue: () -> [PlayTutorialTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

extension View {
    func playTutorialTarget(_ target: PlayTutorialTarget) -> some View {
        anchorPreference(key: PlayTutorialTargetPreferenceKey.self, value: .bounds) { [target: $0] }
    }

    @ViewBuilder
    func playTutorialTarget(_ target: PlayTutorialTarget?) -> some View {
        if let target {
            playTutorialTarget(target)
        } else {
            self
        }
    }
}

struct PlayTutorialOverlay: View {
    @Binding var isPresented: Bool
    let targetFrames: [PlayTutorialTarget: CGRect]
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step = 0
    @State private var arrowBounce: CGFloat = 0
    @State private var ringPulse: CGFloat = 1.0
    @State private var contentOpacity: Double = 1
    @State private var isAdvancing = false

    // MARK: - Step model

    private struct TutStep {
        let icon: String
        let titleES: String, titleEN: String
        let descES: String, descEN: String
        let isWelcome: Bool
        let target: PlayTutorialTarget?
        /// Normalized x/y of the spotlight target (0–1 of full GeometryReader size, incl. safe areas)
        let targetNX: CGFloat
        let targetNY: CGFloat
        /// Spotlight ring size
        let spotW: CGFloat, spotH: CGFloat
        /// true → callout card sits below spotlight; false → above
        let cardBelow: Bool
    }

    // targetNY calibrated for typical iPhone 14/15 Pro (852pt logical height).
    // Adjust constants if layout shifts on future hardware.
    private let allSteps: [TutStep] = [
        // 0 — Welcome (full centred card, no spotlight)
        TutStep(
            icon: "trophy.fill",
            titleES: "BIENVENIDO", titleEN: "WELCOME",
            descES: "Aquí podrás hacer tus apuestas, gestionar tu boleto y demostrar que sabes más que nadie.",
            descEN: "Here you can place your bets, manage your ticket and prove you know more than anyone.",
            isWelcome: true,
            target: nil,
            targetNX: 0.5, targetNY: 0.44,
            spotW: 0, spotH: 0,
            cardBelow: true
        ),
        // 1 — Bets subtab (left button)
        TutStep(
            icon: "list.bullet.rectangle.fill",
            titleES: "ZONA DE APUESTAS", titleEN: "BETS ZONE",
            descES: "Aquí ves todos los partidos disponibles. Pulsa cualquier cuota para añadir un pick a tu boleto.",
            descEN: "Here you see all available matches. Tap any odds button to add a pick to your ticket.",
            isWelcome: false,
            target: .betsTab,
            targetNX: 0.27, targetNY: 0.165,
            spotW: 130, spotH: 44,
            cardBelow: true
        ),
        // 2 — Filter pills
        TutStep(
            icon: "line.3.horizontal.decrease.circle.fill",
            titleES: "FILTRA POR COMPETICIÓN", titleEN: "FILTER BY COMPETITION",
            descES: "Selecciona una liga o deporte para ver solo los partidos que te interesan.",
            descEN: "Select a league or sport to see only the matches that interest you.",
            isWelcome: false,
            target: .filters,
            targetNX: 0.5, targetNY: 0.248,
            spotW: 330, spotH: 46,
            cardBelow: true
        ),
        // 3 — Match card / odds chips
        TutStep(
            icon: "hand.tap.fill",
            titleES: "ELIGE TUS PICKS", titleEN: "MAKE YOUR PICKS",
            descES: "1 = gana el local · X = empate · 2 = gana el visitante. Combina varios picks en un único boleto acumulador.",
            descEN: "1 = home wins · X = draw · 2 = away wins. Combine picks into one accumulator ticket.",
            isWelcome: false,
            target: .firstMatch,
            targetNX: 0.5, targetNY: 0.45,
            spotW: 340, spotH: 110,
            cardBelow: true
        ),
        // 4 — Ticket tray (bottom)
        TutStep(
            icon: "ticket.fill",
            titleES: "REVISA TU APUESTA", titleEN: "REVIEW YOUR BET",
            descES: "Al elegir un pick aparece una bandeja con los datos de tu apuesta. Ajusta el importe, revisa la cuota total y confirma.",
            descEN: "When you pick, a tray appears with your bet details. Adjust your stake, check the total odds and confirm.",
            isWelcome: false,
            target: .ticketTray,
            targetNX: 0.5, targetNY: 0.76,
            spotW: 330, spotH: 92,
            cardBelow: false
        ),
        // 5 — Arena subtab (right button)
        TutStep(
            icon: "bolt.fill",
            titleES: "ARENA 1v1", titleEN: "ARENA 1v1",
            descES: "Cambia a Arena para retar a tus rivales en duelos directos. El que más acierta gana puntos extra.",
            descEN: "Switch to Arena to challenge rivals in direct duels. Most accurate wins extra points.",
            isWelcome: false,
            target: .arenaTab,
            targetNX: 0.73, targetNY: 0.165,
            spotW: 120, spotH: 44,
            cardBelow: true
        ),
    ]

    private var current: TutStep { allSteps[min(step, allSteps.count - 1)] }
    private var isLastStep: Bool { step == allSteps.count - 1 }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dimmed backdrop — tap anywhere to advance (except welcome)
                Color.black.opacity(0.80)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { handleTap() }

                if current.isWelcome {
                    // Full centred welcome card
                    welcomeCard
                        .padding(.horizontal, 28)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.43)
                        .contentShape(Rectangle())
                        .onTapGesture { handleTap() }
                } else {
                    let rect = spotlightRect(in: geo)
                    let tx = rect.midX
                    let ty = rect.midY

                    // Glowing spotlight ring around target element
                    glowRing
                        .frame(width: rect.width, height: rect.height)
                        .scaleEffect(ringPulse)
                        .position(x: tx, y: ty)
                        .animation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.70), value: step)

                    // Arrow + callout card, grouped vertically
                    let groupHalf: CGFloat = 105
                    let rawY: CGFloat = current.cardBelow
                        ? rect.maxY + 16 + groupHalf
                        : rect.minY - 16 - groupHalf
                    let tabBarClearance: CGFloat = 83 // tab bar ~49 + home indicator ~34
                    let clampedY = Swift.min(Swift.max(rawY, groupHalf + 20), geo.size.height - groupHalf - 28 - tabBarClearance)

                    arrowWithCard(cardBelow: current.cardBelow)
                        .frame(width: Swift.min(geo.size.width - 40, 340))
                        .position(x: geo.size.width / 2, y: clampedY)
                        .animation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.70), value: step)
                        .contentShape(Rectangle())
                        .onTapGesture { handleTap() }
                }

                // Bottom bar: skip + step dots
                VStack {
                    Spacer()
                    bottomBar
                        .padding(.bottom, Swift.max(geo.safeAreaInsets.bottom, 12) + 2)
                }
                .allowsHitTesting(true)
                .ignoresSafeArea(edges: .bottom)
            }
            .opacity(contentOpacity)
        }
        .ignoresSafeArea()
        .onAppear {
            launchAnimations()
        }
    }

    // MARK: - Sub-views

    private var welcomeCard: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(DS.accentSoft)
                    .frame(width: 82, height: 82)
                    .overlay(Circle().stroke(DS.accentLine, lineWidth: 1.5))
                    .shadow(color: DS.accent.opacity(0.45), radius: 28)
                Image(systemName: current.icon)
                    .font(.system(size: 30))
                    .foregroundStyle(DS.accent)
                    .accessibilityHidden(true)
            }
            VStack(spacing: 8) {
                Text(appLang == .es ? current.titleES : current.titleEN)
                    .font(.bebas(30))
                    .tracking(1)
                    .foregroundStyle(DS.fg)
                    .multilineTextAlignment(.center)
                Text(appLang == .es ? current.descES : current.descEN)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.fg2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 8) {
                DSButton(
                    title: appLang == .es ? "Ver cómo funciona →" : "Show me how →",
                    style: .primary, fullWidth: true, height: 48
                ) { advance() }
                Button { finish() } label: {
                    Text(appLang == .es ? "Ya sé cómo funciona" : "I already know")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.fg3)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .background(DS.bg1)
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                .stroke(DS.line2, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 32, y: 10)
    }

    private var glowRing: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DS.accent.opacity(0.10))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.accent.opacity(0.85), lineWidth: 1.5)
                .shadow(color: DS.accent.opacity(0.65), radius: 10)
        }
    }

    @ViewBuilder
    private func arrowWithCard(cardBelow: Bool) -> some View {
        if cardBelow {
            // Arrow tip points UP (toward spotlight above), card below
            VStack(spacing: 3) {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(DS.accent)
                    .shadow(color: DS.accent.opacity(0.6), radius: 7)
                    .offset(y: -arrowBounce)
                    .accessibilityHidden(true)
                calloutCard
            }
        } else {
            // Card above, arrow tip points DOWN (toward spotlight below)
            VStack(spacing: 3) {
                calloutCard
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(DS.accent)
                    .shadow(color: DS.accent.opacity(0.6), radius: 7)
                    .offset(y: arrowBounce)
                    .accessibilityHidden(true)
            }
        }
    }

    private var calloutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row: icon badge + title
            HStack(spacing: 10) {
                Image(systemName: current.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.accent)
                    .frame(width: 26, height: 26)
                    .background(DS.accentSoft)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(DS.accentLine, lineWidth: 1))
                Text(appLang == .es ? current.titleES : current.titleEN)
                    .font(.bebas(19))
                    .tracking(0.5)
                    .foregroundStyle(DS.fg)
                    .lineLimit(1)
            }
            // Description
            Text(appLang == .es ? current.descES : current.descEN)
                .font(.system(size: 13))
                .foregroundStyle(DS.fg2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            // CTA or hint
            if isLastStep {
                DSButton(
                    title: appLang == .es ? "¡Empezar a apostar! →" : "Start betting! →",
                    style: .primary, fullWidth: true, height: 42
                ) { finish() }
                .padding(.top, 2)
            } else {
                HStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Text(appLang == .es ? "Toca para continuar" : "Tap to continue")
                            .font(.jbMono(10, weight: .semibold))
                            .tracking(0.3)
                        Image(systemName: "hand.tap")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(DS.fg3)
                }
            }
        }
        .padding(14)
        .background(DS.bg1)
        .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                .stroke(DS.line2, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 14, y: 4)
    }

    private var bottomBar: some View {
        HStack {
            // Skip (hidden on welcome card)
            Button { finish() } label: {
                Text(appLang == .es ? "Saltar" : "Skip")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.fg3)
            }
            .buttonStyle(.plain)
            .padding(.leading, 24)
            .opacity(current.isWelcome ? 0 : 1)
            .allowsHitTesting(!current.isWelcome)

            Spacer()

            // Step dots
            HStack(spacing: 6) {
                ForEach(0..<allSteps.count, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? DS.accent : DS.fg3.opacity(0.30))
                        .frame(width: i == step ? 18 : 6, height: 6)
                        .animation(
                            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.72),
                            value: step
                        )
                }
            }

            Spacer()

            // Invisible mirror to centre dots
            Text(appLang == .es ? "Saltar" : "Skip")
                .font(.system(size: 13, weight: .semibold))
                .padding(.trailing, 24)
                .opacity(0)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Interaction

    private func handleTap() {
        advance()
    }

    private func advance() {
        guard !isAdvancing else { return }
        if isLastStep { finish(); return }
        isAdvancing = true
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.13)) { contentOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            step += 1
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.18)) { contentOpacity = 1 }
            isAdvancing = false
        }
    }

    private func finish() {
        isAdvancing = true
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { isPresented = false }
    }

    private func spotlightRect(in geo: GeometryProxy) -> CGRect {
        let fallback = fallbackSpotlight(in: geo)
        guard let target = current.target,
              let frame = targetFrames[target],
              frame.width > 8,
              frame.height > 8,
              frame.maxY > 0,
              frame.minY < geo.size.height
        else {
            return clampSpotlight(fallback, in: geo)
        }
        return clampSpotlight(adjustedSpotlight(frame, target: target, in: geo), in: geo)
    }

    private func fallbackSpotlight(in geo: GeometryProxy) -> CGRect {
        CGRect(
            x: geo.size.width * current.targetNX - current.spotW / 2,
            y: geo.size.height * current.targetNY - current.spotH / 2,
            width: current.spotW,
            height: current.spotH
        )
    }

    private func adjustedSpotlight(_ frame: CGRect, target: PlayTutorialTarget, in geo: GeometryProxy) -> CGRect {
        switch target {
        case .betsTab, .arenaTab:
            // Tight inset to avoid bleeding into neighbouring tab
            return frame.insetBy(dx: -2, dy: -4)
        case .filters:
            let height = min(max(frame.height + 4, 46), 52)
            return CGRect(
                x: 24,
                y: frame.midY - height / 2,
                width: geo.size.width - 48,
                height: height
            )
        case .firstMatch:
            let width = min(frame.width + 8, geo.size.width - 24)
            let height = min(max(frame.height + 8, 128), 178)
            return CGRect(
                x: geo.size.width / 2 - width / 2,
                y: frame.minY - 4,
                width: width,
                height: height
            )
        case .ticketTray:
            // Tray view is conditional (only rendered when picks exist), so the
            // anchor frame may be stale or missing. Validate that it sits in the
            // bottom portion of the screen, otherwise use a fixed bottom-anchored
            // fallback so the spotlight still points where the tray will appear.
            // Use fixed dimensions so spotlight stays identical across languages
            // (tray content text length differs ES vs EN, so frame.height varies)
            let isFrameValid = frame.minY > geo.size.height * 0.6
            let width = geo.size.width - 48
            let height: CGFloat = 200
            let y: CGFloat
            if isFrameValid {
                y = frame.minY - 4
            } else {
                y = geo.size.height - height - 110 // sit above tab bar
            }
            return CGRect(
                x: geo.size.width / 2 - width / 2,
                y: y,
                width: width,
                height: height
            )
        }
    }

    private func spotlightPadding(for target: PlayTutorialTarget) -> CGFloat {
        switch target {
        case .filters, .ticketTray: return 2
        case .betsTab: return 3
        case .firstMatch: return 5
        case .arenaTab: return 0
        }
    }

    private func clampSpotlight(_ rect: CGRect, in geo: GeometryProxy) -> CGRect {
        let margin: CGFloat = 12
        let maxWidth = max(44, geo.size.width - margin * 2)
        let maxHeight = max(44, geo.size.height - margin * 2)
        let width = min(rect.width, maxWidth)
        let height = min(rect.height, maxHeight)
        let minX = margin
        let maxX = geo.size.width - margin - width
        let minY = margin
        let maxY = geo.size.height - margin - height
        return CGRect(
            x: min(max(rect.minX, minX), maxX),
            y: min(max(rect.minY, minY), maxY),
            width: width,
            height: height
        )
    }

    // MARK: - Animations & timer

    private func launchAnimations() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
            arrowBounce = 7
        }
        withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
            ringPulse = 1.07
        }
    }

}
