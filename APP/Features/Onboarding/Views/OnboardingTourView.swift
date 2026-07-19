import SwiftUI

// MARK: - OnboardingTourView
// 4-screen post-signup tour based on BETSY-handoff-2 design.
// Shown once after account creation; re-triggerable from Profile.

struct OnboardingTourView: View {
    @Binding var hasSeenTour: Bool
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            TabView(selection: $page) {
                TourPage1(appLang: appLang, onSkip: finish, onNext: { next(to: 1) })
                    .tag(0)
                TourPage2(appLang: appLang, onSkip: finish, onNext: { next(to: 2) })
                    .tag(1)
                TourPage3(appLang: appLang, onSkip: finish, onNext: { next(to: 3) })
                    .tag(2)
                TourPage4(appLang: appLang, onSkip: finish, onFinish: finish)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: page)
        }
    }

    private func next(to p: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) {
            page = p
        }
    }

    private func finish() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
            hasSeenTour = true
        }
    }
}

// MARK: - Shared frame

private struct TourScreenFrame<VisualContent: View, TitleContent: View>: View {
    let idx: Int
    let eyebrow: String
    var eyebrowColor: Color = DS.accent
    let titleView: TitleContent
    var ctaLabel: String
    var ctaIsLast: Bool = false
    let onSkip: () -> Void
    let onCTA: () -> Void
    let backdropColors: [(Color, CGFloat, CGFloat)] // (color, x%, y%)
    @ViewBuilder let visualContent: () -> VisualContent

    var body: some View {
        ZStack {
            // Radial backdrop glows
            ForEach(0..<backdropColors.count, id: \.self) { i in
                let item = backdropColors[i]
                RadialGradient(
                    gradient: Gradient(colors: [item.0, .clear]),
                    center: UnitPoint(x: item.1, y: item.2),
                    startRadius: 0,
                    endRadius: 280
                )
                .ignoresSafeArea()
            }

            // Pitch grid
            TourPitchGrid()
                .ignoresSafeArea()

            // Layout
            VStack(spacing: 0) {
                // Safe area top
                Color.clear.frame(height: 54)

                // Header row: step counter + skip
                HStack {
                    TourStepCounter(idx: idx)
                    Spacer()
                    TourSkipButton(onSkip: onSkip)
                }
                .padding(.horizontal, 28)
                .frame(height: 28)

                Spacer().frame(height: 18)

                // Title block (fixed height)
                VStack(alignment: .leading, spacing: 0) {
                    Text(eyebrow)
                        .font(.jbMono(10, weight: .semibold))
                        .tracking(2.4)
                        .textCase(.uppercase)
                        .foregroundStyle(eyebrowColor)
                        .padding(.bottom, 10)
                    titleView
                        .font(.bebas(46))
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)

                Spacer().frame(height: 20)

                // Visual zone — stretches to fill
                visualContent()
                    .padding(.horizontal, 20)

                Spacer(minLength: 0)

                // Primary CTA
                TourCTAButton(label: ctaLabel, isLast: ctaIsLast, action: onCTA)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 18)

                // Pagination dots
                TourPaginationDots(active: idx - 1, total: 4)

                Spacer().frame(height: 32)
            }
        }
    }
}

// MARK: - Atoms

private struct TourPitchGrid: View {
    var body: some View {
        Canvas { ctx, size in
            let stroke = GraphicsContext.Shading.color(Color.white.opacity(0.045))
            let stepV: CGFloat = 24
            let stepH: CGFloat = 24
            var vX: CGFloat = 0
            while vX <= size.width {
                var p = Path(); p.move(to: CGPoint(x: vX, y: 0)); p.addLine(to: CGPoint(x: vX, y: size.height))
                ctx.stroke(p, with: stroke, lineWidth: 1)
                vX += stepV
            }
            var hY: CGFloat = 0
            while hY <= size.height {
                var p = Path(); p.move(to: CGPoint(x: 0, y: hY)); p.addLine(to: CGPoint(x: size.width, y: hY))
                ctx.stroke(p, with: stroke, lineWidth: 1)
                hY += stepH
            }
            // Center circle rings
            let cx = size.width / 2
            let cy: CGFloat = 280
            for r: CGFloat in [120, 220] {
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                var circle = Path(); circle.addEllipse(in: rect)
                ctx.stroke(circle, with: .color(Color.white.opacity(0.04)), lineWidth: 1)
            }
            // Center line
            var cl = Path(); cl.move(to: CGPoint(x: 0, y: cy)); cl.addLine(to: CGPoint(x: size.width, y: cy))
            ctx.stroke(cl, with: .color(Color.white.opacity(0.04)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

private struct TourStepCounter: View {
    let idx: Int
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(DS.accent)
                .frame(width: 5, height: 5)
                .shadow(color: DS.accent, radius: 4)
            Text("\(String(format: "%02d", idx)) / 04")
                .font(.jbMono(10, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(DS.fg2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}

private struct TourSkipButton: View {
    @AppStorage("selectedLanguage") private var appLang: AppLang = .es
    let onSkip: () -> Void
    var body: some View {
        Button(action: onSkip) {
            Text(appLang == .es ? "SALTAR" : "SKIP")
                .font(.jbMono(10, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(DS.fg3)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Color.clear)
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

private struct TourCTAButton: View {
    let label: String
    var isLast: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.system(size: 16, weight: .heavy, design: .default))
                    .tracking(-0.2)
                if !isLast {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .foregroundStyle(DS.accentInk)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(DS.accent)
            .clipShape(Capsule())
            .shadow(color: DS.accent.opacity(0.5), radius: 20, y: 8)
        }
        .buttonStyle(.plain)
    }
}

private struct TourPaginationDots: View {
    let active: Int
    let total: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == active ? DS.accent : Color.white.opacity(0.18))
                    .frame(width: i == active ? 22 : 6, height: 4)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: active)
            }
        }
    }
}

private struct TourGlassCard<Content: View>: View {
    var glow: Bool = false
    var padding: EdgeInsets = .init(top: 14, leading: 14, bottom: 14, trailing: 14)
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.07), Color.white.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                            .stroke(
                                glow
                                    ? DS.accent.opacity(0.3)
                                    : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: glow ? DS.accent.opacity(0.18) : Color.black.opacity(0.3),
                        radius: glow ? 20 : 14, y: 8
                    )
            )
    }
}

private struct TourBadgePill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(DS.accent)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(DS.accent.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(DS.accent.opacity(0.25), lineWidth: 1))
    }
}

private struct TourCrestView: View {
    let initials: String
    let color: Color
    var ring: Bool = false
    var body: some View {
        Text(initials)
            .font(.bebas(18))
            .tracking(0.5)
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(ring ? DS.accent : Color.white.opacity(0.1), lineWidth: ring ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 10, y: 4)
    }
}

// MARK: - SCREEN 1 — Bienvenido

private struct TourPage1: View {
    let appLang: AppLang
    let onSkip: () -> Void
    let onNext: () -> Void

    private let friends: [(initials: String, color: Color, isMe: Bool)] = [
        ("AR", Color(red: 0.49, green: 0.23, blue: 0.93), false),
        ("JM", Color(red: 0.92, green: 0.35, blue: 0.00), false),
        ("YO", Color(red: 0.83, green: 1.00, blue: 0.23), true),
        ("LV", Color(red: 0.06, green: 0.65, blue: 0.91), false),
        ("PD", Color(red: 0.94, green: 0.27, blue: 0.27), false),
    ]

    var body: some View {
        TourScreenFrame(
            idx: 1,
            eyebrow: appLang == .es ? "· Bienvenido a Betsy ·" : "· Welcome to Betsy ·",
            titleView: titleText,
            ctaLabel: appLang == .es ? "Continuar" : "Continue",
            onSkip: onSkip,
            onCTA: onNext,
            backdropColors: [
                (DS.accent.opacity(0.18), 0.5, 0.3),
                (Color.black.opacity(0.7), 0.5, 1.0)
            ]
        ) {
            VStack(spacing: 22) {
                // App logo
                TourLogoView()

                // Friend avatars row
                HStack(spacing: -14) {
                    ForEach(Array(friends.enumerated()), id: \.offset) { idx, f in
                        FriendAvatar(initials: f.initials, color: f.color, isMe: f.isMe)
                            .zIndex(f.isMe ? 5 : Double(friends.count - abs(idx - 2)))
                    }
                }
                .frame(height: 72)

                // Friend count chip
                HStack(spacing: 8) {
                    Circle()
                        .fill(DS.accent)
                        .frame(width: 5, height: 5)
                        .shadow(color: DS.accent, radius: 4)
                    Text(appLang == .es ? "5 amigos en tu liga" : "5 friends in your league")
                        .font(.jbMono(10, weight: .semibold))
                        .tracking(1.8)
                        .textCase(.uppercase)
                        .foregroundStyle(DS.fg2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))

                // Subtitle
                Group {
                    if appLang == .es {
                        Text("Compite con amigos usando apuestas virtuales. ")
                            .foregroundStyle(DS.fg2)
                        + Text("Sin dinero real.")
                            .foregroundStyle(DS.fg)
                    } else {
                        Text("Compete with friends using virtual points. ")
                            .foregroundStyle(DS.fg2)
                        + Text("No real money.")
                            .foregroundStyle(DS.fg)
                    }
                }
                .font(.system(size: 15, weight: .medium))
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var titleText: some View {
        Group {
            if appLang == .es {
                Text("Tu liga.\nTus picks.\n")
                + Text("Tu ranking.").foregroundColor(DS.accent)
            } else {
                Text("Your league.\nYour picks.\n")
                + Text("Your ranking.").foregroundColor(DS.accent)
            }
        }
    }
}

private struct TourLogoView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.10, green: 0.10, blue: 0.12),
                                 Color(red: 0.05, green: 0.05, blue: 0.07)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "sportscourt.fill")
                .font(.system(size: 44, weight: .black))
                .foregroundStyle(DS.accent)
        }
        .frame(width: 100, height: 100)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(DS.accent.opacity(0.45), lineWidth: 1.5)
        )
        .shadow(color: DS.accent.opacity(0.45), radius: 30, y: 16)
        .shadow(color: Color.black.opacity(0.6), radius: 20, y: 10)
        .accessibilityHidden(true)
    }
}

private struct FriendAvatar: View {
    let initials: String
    let color: Color
    let isMe: Bool
    private let size: CGFloat

    init(initials: String, color: Color, isMe: Bool) {
        self.initials = initials
        self.color = color
        self.isMe = isMe
        self.size = isMe ? 66 : 56
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: isMe
                            ? [DS.accent, Color(red: 0.66, green: 0.84, blue: 0.13)]
                            : [color, color.opacity(0.67)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle().stroke(DS.bg, lineWidth: 3)
                )
                .overlay(
                    Circle().stroke(
                        isMe ? DS.accent : Color.white.opacity(0.08),
                        lineWidth: isMe ? 2 : 1
                    ).padding(3)
                )
                .shadow(
                    color: isMe ? DS.accent.opacity(0.55) : Color.black.opacity(0.5),
                    radius: isMe ? 16 : 10, y: 4
                )

            // Person icon
            Image(systemName: "person.fill")
                .font(.system(size: isMe ? 30 : 24, weight: .bold))
                .foregroundStyle(isMe ? DS.accentInk : Color.white)
                .opacity(0.92)
                .frame(width: size, height: size)

            if isMe {
                Text("YO")
                    .font(.bebas(9))
                    .tracking(0.5)
                    .foregroundStyle(DS.accent)
                    .frame(width: 18, height: 18)
                    .background(DS.bg)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(DS.accent, lineWidth: 1.5))
                    .offset(x: 2, y: 2)
            }
        }
    }
}

// MARK: - SCREEN 2 — Cómo funciona

private struct TourPage2: View {
    let appLang: AppLang
    let onSkip: () -> Void
    let onNext: () -> Void

    var body: some View {
        TourScreenFrame(
            idx: 2,
            eyebrow: appLang == .es ? "02 · cómo funciona" : "02 · how it works",
            titleView: titleText,
            ctaLabel: appLang == .es ? "Continuar" : "Continue",
            onSkip: onSkip,
            onCTA: onNext,
            backdropColors: [
                (DS.accent.opacity(0.10), 0.5, 0.35)
            ]
        ) {
            VStack(spacing: 10) {
                // Match card
                TourGlassCard(glow: true) {
                    VStack(spacing: 0) {
                        // Match header
                        HStack {
                            Text("NBA · 21:30")
                                .font(.jbMono(10))
                                .tracking(1.8)
                                .textCase(.uppercase)
                                .foregroundStyle(DS.fg3)
                            Spacer()
                            HStack(spacing: 5) {
                                Circle().fill(DS.loss).frame(width: 5, height: 5)
                                Text("LIVE SOON")
                                    .font(.jbMono(10))
                                    .tracking(1.6)
                                    .foregroundStyle(DS.loss)
                            }
                        }
                        .padding(.bottom, 12)

                        // Teams
                        HStack {
                            VStack(spacing: 6) {
                                TourCrestView(initials: "LAL", color: Color(red: 0.33, green: 0.15, blue: 0.51))
                                Text("Lakers")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(DS.fg)
                            }
                            .frame(width: 80)

                            Spacer()
                            VStack(spacing: 3) {
                                Text("VS")
                                    .font(.bebas(28))
                                    .tracking(0.5)
                                    .foregroundStyle(DS.fg3)
                                Text("CRYPTO ARENA")
                                    .font(.jbMono(8))
                                    .tracking(1.6)
                                    .foregroundStyle(DS.fg3)
                            }
                            Spacer()

                            VStack(spacing: 6) {
                                TourCrestView(initials: "BOS", color: Color(red: 0.0, green: 0.48, blue: 0.20))
                                Text("Celtics")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(DS.fg)
                            }
                            .frame(width: 80)
                        }
                        .padding(.bottom, 12)

                        // Odds row
                        HStack(spacing: 6) {
                            OddButton(label: "1", value: "1.85", active: false)
                            OddButton(label: "2", value: "2.50", active: true)
                        }
                    }
                }

                // Bet math card
                TourGlassCard {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appLang == .es ? "APUESTA" : "STAKE")
                                    .font(.jbMono(8))
                                    .tracking(1.8)
                                    .foregroundStyle(DS.fg3)
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text("10")
                                        .font(.bebas(26))
                                        .foregroundStyle(DS.fg)
                                    Text("PTS")
                                        .font(.jbMono(10))
                                        .foregroundStyle(DS.fg3)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(DS.fg3)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(appLang == .es ? "GANAS" : "YOU WIN")
                                    .font(.jbMono(8))
                                    .tracking(1.8)
                                    .foregroundStyle(DS.accent)
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text("25")
                                        .font(.bebas(26))
                                        .foregroundStyle(DS.accent)
                                    Text("PTS")
                                        .font(.jbMono(10))
                                        .foregroundStyle(DS.accent.opacity(0.7))
                                }
                            }
                        }
                        .padding(.bottom, 8)

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.bottom, 8)

                        HStack {
                            Text(appLang == .es ? "CUOTA · @2.50" : "ODDS · @2.50")
                                .font(.jbMono(9))
                                .tracking(1.0)
                                .foregroundStyle(DS.fg3)
                            Spacer()
                            Text(appLang == .es ? "+15 PTS BENEFICIO" : "+15 PTS PROFIT")
                                .font(.jbMono(9))
                                .tracking(1.0)
                                .foregroundStyle(DS.fg2)
                        }
                    }
                }

                // Pills
                HStack(spacing: 6) {
                    TourBadgePill(text: appLang == .es ? "3 picks / día" : "3 picks / day")
                    TourBadgePill(text: appLang == .es ? "Elige bien" : "Pick wisely")
                    TourBadgePill(text: "+ cuota = + pts")
                }
                .padding(.top, 2)
            }
        }
    }

    private var titleText: some View {
        Group {
            if appLang == .es {
                Text("Elige picks.\n")
                + Text("Arriesga puntos.").foregroundColor(DS.accent)
                + Text(" Gana más.")
            } else {
                Text("Make picks.\n")
                + Text("Risk points.").foregroundColor(DS.accent)
                + Text(" Win more.")
            }
        }
    }
}

private struct OddButton: View {
    let label: String
    let value: String
    let active: Bool
    var body: some View {
        HStack {
            Text(label)
                .font(.jbMono(11))
                .tracking(1.0)
                .foregroundStyle(active ? DS.accentInk.opacity(0.65) : DS.fg.opacity(0.5))
            Spacer()
            Text(value)
                .font(.jbMono(14, weight: .bold))
                .foregroundStyle(active ? DS.accentInk : DS.fg)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(active ? DS.accent : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(active ? DS.accent : Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: active ? DS.accent.opacity(0.45) : .clear, radius: 10, y: 4)
    }
}

// MARK: - SCREEN 3 — Clasificación

private struct TourPage3: View {
    let appLang: AppLang
    let onSkip: () -> Void
    let onNext: () -> Void

    private let leaderboard: [(pos: Int, name: String, pts: String, delta: String, colorHex: String, isMe: Bool, down: Bool)] = [
        (1, "Marcos V.", "1.820", "+85",  "ea580c", false, false),
        (2, "Júlia P.",  "1.610", "+40",  "7c3aed", false, false),
        (3, "Tú",        "1.450", "+120", "d4ff3a", true,  false),
        (4, "Diego R.",  "1.290", "−30",  "0ea5e9", false, true),
        (5, "Laura B.",  "1.180", "+12",  "ef4444", false, false),
    ]

    var body: some View {
        TourScreenFrame(
            idx: 3,
            eyebrow: appLang == .es ? "03 · clasificación" : "03 · rankings",
            titleView: titleText,
            ctaLabel: appLang == .es ? "Continuar" : "Continue",
            onSkip: onSkip,
            onCTA: onNext,
            backdropColors: [
                (DS.accent.opacity(0.10), 0.5, 0.6)
            ]
        ) {
            VStack(spacing: 10) {
                // Stats row
                HStack(spacing: 8) {
                    TourStatBox(label: appLang == .es ? "POSICIÓN" : "RANK",   value: "#3",    sub: "↑ 2",    good: true)
                    TourStatBox(label: appLang == .es ? "PUNTOS" : "POINTS",   value: "1.450", sub: appLang == .es ? "semana" : "week",  good: false)
                    TourStatBox(label: appLang == .es ? "ACIERTO" : "HIT RATE",value: "68%",   sub: "17 / 25", good: false)
                }

                // Leaderboard card
                TourGlassCard(padding: .init(top: 12, leading: 12, bottom: 12, trailing: 12)) {
                    VStack(spacing: 0) {
                        HStack {
                            Text(appLang == .es ? "Liga · La Quiniela" : "League · La Quiniela")
                                .font(.jbMono(10))
                                .tracking(1.8)
                                .textCase(.uppercase)
                                .foregroundStyle(DS.fg3)
                            Spacer()
                            Text("JORN. 12")
                                .font(.jbMono(10))
                                .tracking(1.8)
                                .foregroundStyle(DS.accent)
                        }
                        .padding(.bottom, 4)

                        ForEach(leaderboard, id: \.pos) { row in
                            LeaderboardRow(row: row)
                        }
                    }
                }

                // Pills
                HStack(spacing: 6) {
                    TourBadgePill(text: appLang == .es ? "Sube en la tabla" : "Climb the table")
                    TourBadgePill(text: appLang == .es ? "Compite" : "Compete")
                    TourBadgePill(text: appLang == .es ? "Cada pick cuenta" : "Every pick counts")
                }
                .padding(.top, 2)
            }
        }
    }

    private var titleText: some View {
        Group {
            if appLang == .es {
                Text("Cada pick\n")
                + Text("cuenta.").foregroundColor(DS.accent)
            } else {
                Text("Every pick\n")
                + Text("counts.").foregroundColor(DS.accent)
            }
        }
    }
}

private struct TourStatBox: View {
    let label: String
    let value: String
    let sub: String
    let good: Bool
    var body: some View {
        TourGlassCard(padding: .init(top: 10, leading: 10, bottom: 10, trailing: 10)) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.jbMono(8))
                    .tracking(2.0)
                    .textCase(.uppercase)
                    .foregroundStyle(DS.fg3)
                Text(value)
                    .font(.bebas(22))
                    .foregroundStyle(DS.fg)
                Text(sub)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(good ? DS.accent : DS.fg3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LeaderboardRow: View {
    let row: (pos: Int, name: String, pts: String, delta: String, colorHex: String, isMe: Bool, down: Bool)

    var body: some View {
        HStack(spacing: 10) {
            Text("#\(row.pos)")
                .font(.jbMono(11, weight: .bold))
                .foregroundStyle(row.isMe ? DS.accent : DS.fg3)
                .frame(width: 24, alignment: .center)

            // Avatar
            Circle()
                .fill(
                    row.isMe
                        ? AnyShapeStyle(LinearGradient(colors: [DS.accent, Color(red: 0.66, green: 0.84, blue: 0.13)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color(dsHex: row.colorHex))
                )
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))

            Text(row.name)
                .font(.system(size: 13, weight: row.isMe ? .heavy : .semibold))
                .foregroundStyle(row.isMe ? DS.fg : DS.fg2)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(row.pts)
                    .font(.bebas(16))
                    .foregroundStyle(row.isMe ? DS.accent : DS.fg)
                Text(row.delta)
                    .font(.jbMono(9))
                    .tracking(1.0)
                    .foregroundStyle(row.down ? DS.loss : DS.accent)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(row.isMe ? DS.accent.opacity(0.08) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(row.isMe ? DS.accent.opacity(0.35) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - SCREEN 4 — Arena 1v1

private struct TourPage4: View {
    let appLang: AppLang
    let onSkip: () -> Void
    let onFinish: () -> Void

    var body: some View {
        TourScreenFrame(
            idx: 4,
            eyebrow: "04 · ARENA 1V1",
            eyebrowColor: DS.loss,
            titleView: titleText,
            ctaLabel: appLang == .es ? "Empezar" : "Let's go",
            ctaIsLast: true,
            onSkip: onFinish,
            onCTA: onFinish,
            backdropColors: [
                (DS.arena.opacity(0.28), 0.18, 0.32),
                (DS.accent.opacity(0.22), 0.82, 0.32),
                (Color.black.opacity(0.6), 0.5, 1.0)
            ]
        ) {
            VStack(spacing: 12) {
                // Duel card
                TourGlassCard(glow: true, padding: .init(top: 0, leading: 0, bottom: 0, trailing: 0)) {
                    VStack(spacing: 0) {
                        // Header strip
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(DS.loss)
                                    .frame(width: 5, height: 5)
                                    .shadow(color: DS.loss, radius: 4)
                                Text(appLang == .es ? "DUELO ABIERTO" : "OPEN DUEL")
                                    .font(.jbMono(10))
                                    .tracking(2.2)
                                    .foregroundStyle(DS.loss)
                            }
                            Spacer()
                            Text("02:14:36")
                                .font(.jbMono(10))
                                .tracking(1.8)
                                .foregroundStyle(DS.fg3)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [DS.arena.opacity(0.10), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )

                        Divider().background(Color.white.opacity(0.06))

                        // Players
                        HStack(alignment: .top, spacing: 0) {
                            // You
                            ArenaDuelPlayer(
                                initial: "YO",
                                name: appLang == .es ? "Tú" : "You",
                                pts: "1.450",
                                pick: "RMA",
                                color: DS.accent,
                                textColor: DS.accentInk,
                                glowColor: DS.accent
                            )

                            // VS
                            VStack(spacing: 4) {
                                Text("VS")
                                    .font(.bebas(36))
                                    .foregroundStyle(DS.fg)
                                    .shadow(color: DS.arena.opacity(0.5), radius: 12)
                                Text(appLang == .es ? "EL CLÁSICO" : "EL CLÁSICO")
                                    .font(.jbMono(8))
                                    .tracking(1.6)
                                    .foregroundStyle(DS.fg3)
                            }
                            .frame(width: 70)
                            .padding(.top, 18)

                            // Opponent
                            ArenaDuelPlayer(
                                initial: "JM",
                                name: "Javi M.",
                                pts: "1.290",
                                pick: "BAR",
                                color: DS.loss,
                                textColor: .white,
                                glowColor: DS.arena
                            )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)

                        Divider().background(Color.white.opacity(0.08))

                        // Pot strip
                        HStack {
                            Text(appLang == .es ? "· Premio del bote ·" : "· Jackpot prize ·")
                                .font(.jbMono(10))
                                .tracking(2.0)
                                .textCase(.uppercase)
                                .foregroundStyle(DS.fg3)
                            Spacer()
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("100")
                                    .font(.bebas(26))
                                    .foregroundStyle(DS.accent)
                                Text("PTS")
                                    .font(.jbMono(10))
                                    .foregroundStyle(DS.fg2)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.25))
                    }
                }

                // Pills
                HStack(spacing: 6) {
                    TourBadgePill(text: appLang == .es ? "Reta a un amigo" : "Challenge friends")
                    TourBadgePill(text: appLang == .es ? "Elige tu pick" : "Pick your side")
                    TourBadgePill(text: appLang == .es ? "Puntos extra" : "Extra points")
                }
                .padding(.top, 2)
            }
        }
    }

    private var titleText: some View {
        Group {
            if appLang == .es {
                Text("Reta a un amigo.\n")
                + Text("El que\nacierte gana.").foregroundColor(DS.accent)
            } else {
                Text("Challenge a friend.\n")
                + Text("Best pick\nwins.").foregroundColor(DS.accent)
            }
        }
    }
}

private struct ArenaDuelPlayer: View {
    let initial: String
    let name: String
    let pts: String
    let pick: String
    let color: Color
    let textColor: Color
    let glowColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .overlay(
                    Text(initial)
                        .font(.bebas(22))
                        .tracking(0.5)
                        .foregroundStyle(textColor)
                )
                .overlay(
                    Circle().stroke(glowColor.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: glowColor.opacity(0.5), radius: 16, y: 6)

            VStack(spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(DS.fg)
                Text("\(pts) PTS")
                    .font(.jbMono(9))
                    .tracking(1.2)
                    .foregroundStyle(DS.fg3)
            }

            Text(pick)
                .font(.jbMono(9))
                .tracking(1.6)
                .foregroundStyle(color)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }
}

// Color(dsHex:) is defined globally in DS.swift
