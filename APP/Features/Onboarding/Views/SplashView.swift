import SwiftUI

// MARK: - Splash · "B / BETSY · SOCIAL · LEAGUE · ARENA · CARGANDO TEMPORADA"
//        Matches design 01.1 (Stadium dark)

struct SplashView: View {
    @Binding var showSplash: Bool
    @EnvironmentObject var leagueService: LeagueService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var logoOpacity = 0.0
    @State private var logoScale: CGFloat = 0.86
    @State private var glowOpacity = 0.0
    @State private var dotOpacity = 0.0
    @State private var minTimeElapsed = false

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            // Subtle tactical grid (only behind the logo)
            Canvas { context, size in
                var p = Path()
                let step: CGFloat = 28
                var x: CGFloat = 0
                while x < size.width {
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y < size.height {
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(p, with: .color(Color.white.opacity(0.024)),
                              style: StrokeStyle(lineWidth: 0.5))
            }
            .ignoresSafeArea()

            // Lime ambient glow
            Circle()
                .fill(Theme.accent.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .opacity(glowOpacity)

            VStack(spacing: 20) {
                Spacer()

                Image("BetsyLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 190, height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
                    .shadow(color: Theme.accent.opacity(0.24), radius: 24, x: 0, y: 0)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                // "BETSY" wordmark
                Text("BETSY")
                    .font(.system(size: 48, weight: .black))
                    .tracking(8)
                    .foregroundStyle(Color.white)
                    .opacity(logoOpacity)

                // Tagline
                Text("SOCIAL  ·  LEAGUE  ·  ARENA")
                    .font(.system(size: 11, weight: .black))
                    .tracking(3.0)
                    .foregroundStyle(Color.white.opacity(0.62))
                    .opacity(logoOpacity)

                Spacer()

                // Loading footer
                HStack(spacing: 8) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 6, height: 6)
                        .opacity(dotOpacity)
                    Text("CARGANDO TEMPORADA")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2.0)
                        .foregroundStyle(Color.white.opacity(0.68))
                }
                .padding(.bottom, 40)
                .opacity(logoOpacity)
            }
        }
        .onAppear {
            if reduceMotion {
                logoOpacity = 1
                logoScale = 1
                glowOpacity = 0.55
                dotOpacity = 1
            } else {
                withAnimation(.easeOut(duration: 0.36)) {
                    logoOpacity = 1
                    glowOpacity = 1
                }
                withAnimation(.spring(response: 0.78, dampingFraction: 0.82)) {
                    logoScale = 1
                }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    dotOpacity = 1
                }
            }
            // Min display time so the brand actually breathes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                minTimeElapsed = true
                tryDismiss()
            }
            // Hard cap at 3.5s in case Firestore never settles
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                if showSplash {
                    dismissSplash()
                }
            }
        }
        .onChange(of: leagueService.isLoading) { _, _ in tryDismiss() }
    }

    private func tryDismiss() {
        guard minTimeElapsed, !leagueService.isLoading, showSplash else { return }
        dismissSplash()
    }

    private func dismissSplash() {
        if reduceMotion {
            showSplash = false
        } else {
            withAnimation(.easeInOut(duration: 0.30)) { showSplash = false }
        }
    }
}
