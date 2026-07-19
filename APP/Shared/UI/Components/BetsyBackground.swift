import SwiftUI

// Dark stadium background with subtle tactical grid + lime accent node
struct BetsyBackground: View {

    private let base        = Color(red: 0.039, green: 0.039, blue: 0.047)   // #0a0a0c
    private let gridColor   = Color.white.opacity(0.035)
    private let guideColor  = Color.white.opacity(0.055)
    private let pathColor   = Color.white.opacity(0.06)
    private let nodeColor   = Color(red: 0.831, green: 1.000, blue: 0.227).opacity(0.55)  // lime

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                base

                Canvas { context, canvasSize in
                    let w = canvasSize.width
                    let h = canvasSize.height

                    // ── Fine background grid ────────────────────────────────
                    var grid = Path()
                    let vStep = max(44, w / 7.0)
                    let hStep = max(54, h / 12.0)

                    var x: CGFloat = 0
                    while x <= w { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: h)); x += vStep }
                    var y: CGFloat = 0
                    while y <= h { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: w, y: y)); y += hStep }

                    context.stroke(grid, with: .color(gridColor),
                                   style: StrokeStyle(lineWidth: 0.6, lineCap: .round))

                    // ── Court / field reference lines ───────────────────────
                    let inset: CGFloat = 24
                    var guides = Path()
                    guides.addRect(CGRect(x: inset, y: inset,
                                         width: max(0, w - inset * 2),
                                         height: max(0, h - inset * 2)))
                    guides.move(to: CGPoint(x: w * 0.5, y: inset))
                    guides.addLine(to: CGPoint(x: w * 0.5, y: h - inset))
                    guides.move(to: CGPoint(x: inset, y: h * 0.5))
                    guides.addLine(to: CGPoint(x: w - inset, y: h * 0.5))

                    let cr = min(w, h) * 0.18
                    guides.addEllipse(in: CGRect(x: (w - cr) * 0.5, y: (h - cr) * 0.5, width: cr, height: cr))

                    context.stroke(guides, with: .color(guideColor),
                                   style: StrokeStyle(lineWidth: 0.8, lineCap: .square))

                    // ── Abstract motion trajectories ────────────────────────
                    var traj = Path()
                    traj.move(to: CGPoint(x: w * 0.08, y: h * 0.78))
                    traj.addCurve(to: CGPoint(x: w * 0.85, y: h * 0.20),
                                  control1: CGPoint(x: w * 0.34, y: h * 0.48),
                                  control2: CGPoint(x: w * 0.60, y: h * 0.10))
                    traj.move(to: CGPoint(x: w * 0.16, y: h * 0.18))
                    traj.addCurve(to: CGPoint(x: w * 0.90, y: h * 0.70),
                                  control1: CGPoint(x: w * 0.38, y: h * 0.08),
                                  control2: CGPoint(x: w * 0.66, y: h * 0.94))

                    context.stroke(traj, with: .color(pathColor),
                                   style: StrokeStyle(lineWidth: 0.9, lineCap: .round, dash: [3, 9]))

                    // ── Lime tactical node points ───────────────────────────
                    let nodes: [CGPoint] = [
                        CGPoint(x: w * 0.16, y: h * 0.18),
                        CGPoint(x: w * 0.50, y: h * 0.50),
                        CGPoint(x: w * 0.85, y: h * 0.20),
                        CGPoint(x: w * 0.08, y: h * 0.78),
                        CGPoint(x: w * 0.84, y: h * 0.70)
                    ]
                    var nodePath = Path()
                    for p in nodes {
                        nodePath.addEllipse(in: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5))
                    }
                    context.fill(nodePath, with: .color(nodeColor))
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .allowsHitTesting(false)
    }
}
