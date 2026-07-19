import SwiftUI

struct ArenaIncomingChallengeSurface: View {
    let duel: ArenaDuel
    let lang: AppLang
    let onAccept: () -> Void
    let onReject: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var pulsePhase: Double = 0

    private var heroTitle: String {
        lang == .es ? "\(duel.challengerName) te reta!" : "\(duel.challengerName) challenges you!"
    }

    private var subtitleText: String {
        lang == .es
            ? "Un duelo 1v1 con \(duel.matches.count) partidos aleatorios de cualquier deporte."
            : "A 1v1 duel on \(duel.matches.count) random matches across any sport."
    }

    private var stakeText: String {
        "\(duel.wager) pts"
    }

    private var uniqueLeagues: [String] {
        duel.matches.reduce(into: [String]()) { partial, match in
            if !partial.contains(match.league) { partial.append(match.league) }
        }
    }

    private var leaguesSummary: String {
        if uniqueLeagues.isEmpty {
            return lang == .es ? "Partidos por revelar" : "Matches to be revealed"
        }
        if uniqueLeagues.count > 3 {
            let head = uniqueLeagues.prefix(3).joined(separator: " · ")
            return "\(head) +\(uniqueLeagues.count - 3)"
        }
        return uniqueLeagues.joined(separator: " · ")
    }

    var body: some View {
        ZStack {
            // Vibrant background wash
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.90, blue: 0.88),
                    Color(red: 0.96, green: 0.88, blue: 1.00)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating colored blobs for game-feel
            Circle()
                .fill(Theme.hot.opacity(0.25))
                .frame(width: 240, height: 240)
                .blur(radius: 80)
                .offset(x: -120, y: -220)
                .scaleEffect(reduceMotion ? 1 : 1 + 0.05 * pulsePhase)
            Circle()
                .fill(Theme.electric.opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: 130, y: 260)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    heroBolt
                        .padding(.top, 14)

                    VStack(spacing: 10) {
                        Text(heroTitle)
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(Theme.bg)
                            .multilineTextAlignment(.center)

                        Text(subtitleText)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.bg.opacity(0.78))
                            .multilineTextAlignment(.center)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .padding(.horizontal, 24)

                    // Stake hero
                    prizeHeroCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .padding(.horizontal, 20)

                    // Split wager stats
                    HStack(spacing: 10) {
                        statChip(
                            icon: "figure.arms.open",
                            title: lang == .es ? "RIVAL" : "RIVAL",
                            value: "\(duel.wager)",
                            unit: "pts",
                            color: Theme.electric
                        )
                        statChip(
                            icon: "flame.fill",
                            title: lang == .es ? "TÚ" : "YOU",
                            value: "\(duel.wager)",
                            unit: "pts",
                            color: Theme.hot
                        )
                    }
                    .opacity(appeared ? 1 : 0)
                    .padding(.horizontal, 20)

                    // Info rows
                    VStack(spacing: 10) {
                        infoRow(
                            icon: "sportscourt.fill",
                            color: Theme.sun,
                            title: lang == .es ? "Partidos" : "Matches",
                            value: "\(duel.matches.count)"
                        )
                        infoRow(
                            icon: "globe",
                            color: Theme.skyPop,
                            title: lang == .es ? "Ligas" : "Leagues",
                            value: leaguesSummary
                        )
                        infoRow(
                            icon: "target",
                            color: Theme.violetPop,
                            title: lang == .es ? "Picks" : "Picks",
                            value: lang == .es ? "Elige 2 o 3 al aceptar" : "Pick 2 or 3 on accept"
                        )
                    }
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)

                    VStack(spacing: 12) {
                        BetsyButton(
                            title: lang == .es ? "Aceptar y elegir picks" : "Accept & choose picks",
                            systemImage: "bolt.fill",
                            style: .arena
                        ) {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            onAccept()
                        }

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onReject()
                        }) {
                            Text(lang == .es ? "Rechazar y cancelar reto" : "Reject & cancel challenge")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(Theme.bg.opacity(0.72))
                                .underline(true, color: Theme.bg.opacity(0.48))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)

                    Spacer(minLength: 20)
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            if reduceMotion {
                appeared = true
                pulsePhase = 0
            } else {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.78).delay(0.06)) {
                    appeared = true
                }
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    pulsePhase = 1
                }
            }
        }
    }

    // MARK: Hero bolt icon

    private var heroBolt: some View {
        ZStack {
            Circle()
                .stroke(Theme.hot.opacity(0.36), lineWidth: 2)
                .frame(width: 110, height: 110)
                .scaleEffect(reduceMotion ? 1 : 1 + 0.65 * pulsePhase)
                .opacity(reduceMotion ? 0 : 1 - pulsePhase)
                .opacity(appeared ? 1 : 0)

            Circle()
                .stroke(Theme.hot.opacity(0.18), lineWidth: 1)
                .frame(width: 100, height: 100)
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)

            Circle()
                .fill(Theme.arenaGradient)
                .frame(width: 72, height: 72)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(color: Theme.hot.opacity(0.7), radius: 22, x: 0, y: 10)
                .scaleEffect(appeared ? 1 : 0.5)

            Image(systemName: "bolt.fill")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Color.white)
                .scaleEffect(reduceMotion ? 1 : 1 + 0.14 * pulsePhase)
                .rotationEffect(.degrees(reduceMotion ? 0 : pulsePhase * 10 - 5))
        }
        .accessibilityHidden(true)
    }

    // MARK: Stake hero card

    private var prizeHeroCard: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(lang == .es ? "APUESTA BLOQUEADA" : "LOCKED STAKE")
                .font(.system(size: 11, weight: .black))
                .tracking(1.4)
                .foregroundStyle(Color.white.opacity(0.82))
            Text(stakeText)
                .font(.system(size: 44, weight: .black))
                .foregroundStyle(Color.white)
            Text(lang == .es ? "Si aciertas, ganas según tu cuota." : "Win by your own odds.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(Theme.winGradient)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Theme.lime.opacity(0.45), radius: 22, x: 0, y: 12)
    }

    // MARK: Stat chip

    private func statChip(icon: String, title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.white)
                    .frame(width: 22, height: 22)
                    .background(color)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(Theme.bg.opacity(0.75))
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Theme.bg)
                Text(unit)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.bg.opacity(0.75))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.24), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: color.opacity(0.14), radius: 10, x: 0, y: 4)
    }

    // MARK: Info row

    private func infoRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.white)
                .frame(width: 30, height: 30)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: color.opacity(0.28), radius: 6, x: 0, y: 3)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Theme.bg.opacity(0.82))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.bg)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
