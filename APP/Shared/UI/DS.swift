import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - BETSY Design System
// Direct SwiftUI port of tokens.css (Claude Design wireframes)

enum DS {
    // MARK: - Background layers
    static let bg  = Color(dsHex: "0a0a0b")
    static let bg1 = Color(dsHex: "111114")
    static let bg2 = Color(dsHex: "18181d")
    static let bg3 = Color(dsHex: "21212a")

    // MARK: - Border / divider
    static let line  = Color.white.opacity(0.32)
    static let line2 = Color.white.opacity(0.38)

    // MARK: - Foreground text
    static let fg  = Color(dsHex: "f4f4f0")
    static let fg2 = Color(dsHex: "b8b8b0")
    static let fg3 = Color(dsHex: "9c9c95")
    static let fg4 = Color(dsHex: "737370")

    // MARK: - Accent — Electric Lime #d4ff3a
    static let accent     = Color(dsHex: "d4ff3a")
    static let accentInk  = Color(dsHex: "0a0a0b")
    static let accentSoft = Color(red: 212/255, green: 255/255, blue: 58/255).opacity(0.16)
    static let accentLine = Color(red: 212/255, green: 255/255, blue: 58/255).opacity(0.32)

    // MARK: - Semantic status colors
    static let win    = Color(dsHex: "6cf09a")  // green
    static let loss   = Color(dsHex: "ff5a4a")  // red
    static let warn   = Color(dsHex: "ffc233")  // amber
    static let arena  = Color(dsHex: "ff2d55")  // magenta-red
    static let arena2 = Color(dsHex: "ff8a2d")  // orange

    // MARK: - Corner radii
    static let rSm: CGFloat = 8
    static let rMd: CGFloat = 14
    static let rLg: CGFloat = 22
    static let rXl: CGFloat = 32

    // MARK: - Screen rhythm
    static let screenHPad: CGFloat = 20

    // MARK: - Card component
    struct Card: ViewModifier {
        func body(content: Content) -> some View {
            content
                .background(DS.bg1)
                .clipShape(RoundedRectangle(cornerRadius: DS.rLg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                        .stroke(DS.line, lineWidth: 1)
                )
        }
    }
}

// MARK: - Color from hex string
extension Color {
    init(dsHex hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - View helpers
extension View {
    /// Apply DS card style
    func dsCard() -> some View { modifier(DS.Card()) }

    /// Pill/capsule shape with border
    func dsPill(bg: Color = DS.bg2, border: Color = DS.line) -> some View {
        self.padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(bg)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(border, lineWidth: 1))
    }

    /// Back button circle (bg-2 + border)
    func dsBackButton() -> some View {
        self.frame(width: 44, height: 44)
            .background(DS.bg2)
            .clipShape(Circle())
            .overlay(Circle().stroke(DS.line, lineWidth: 1))
    }
}

// MARK: - Custom font helpers

extension Font {
    /// Bebas Neue — display / headlines
    static func bebas(_ size: CGFloat) -> Font {
        .custom("BebasNeue-Regular", size: size, relativeTo: .largeTitle)
    }

    /// JetBrains Mono — monospaced numbers / labels
    static func jbMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold:      name = "JetBrainsMono-Bold"
        case .semibold:  name = "JetBrainsMono-SemiBold"
        case .medium:    name = "JetBrainsMono-Medium"
        case .heavy, .black: name = "JetBrainsMono-ExtraBold"
        default:         name = "JetBrainsMono-Regular"
        }
        return .custom(name, size: max(size, 11), relativeTo: .caption)
    }
}

// MARK: - Reusable DS components

/// Eyebrow label: JetBrains Mono 10px uppercase tracking
struct DSEyebrow: View {
    let text: String
    var color: Color = DS.fg3
    var body: some View {
        Text(text)
            .textCase(.uppercase)
            .font(.jbMono(11, weight: .semibold))
            .tracking(1.8)
            .foregroundStyle(color)
    }
}

/// Display headline: Bebas Neue large text
struct DSDisplay: View {
    let text: String
    var size: CGFloat = 44
    var color: Color = DS.fg
    var lineSpacing: CGFloat = 0
    var body: some View {
        Text(text)
            .font(.bebas(size))
            .tracking(0.5)
            .foregroundStyle(color)
            .lineSpacing(lineSpacing)
    }
}

/// Pill component
struct DSPill: View {
    let text: String
    var bg: Color = DS.bg2
    var border: Color = DS.line
    var fg: Color = DS.fg2
    var fontSize: CGFloat = 11
    var dot: Color? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let dot {
                Circle()
                    .fill(dot)
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(.system(size: fontSize, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(fg)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(bg)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(border, lineWidth: 1))
    }
}

/// Primary button (lime)
struct DSButton: View {
    let title: String
    var style: Style = .primary
    var fullWidth: Bool = false
    var height: CGFloat = 52
    let action: () -> Void

    enum Style {
        case primary   // lime fill
        case ghost     // transparent + line2 border
        case dark      // bg2 fill
        case arena     // arena red fill
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .tracking(-0.2)
                .foregroundStyle(fgColor)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(height: height)
                .padding(.horizontal, fullWidth ? 0 : 22)
                .background(bgColor)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(borderColor, lineWidth: style == .ghost ? 1 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title.replacingOccurrences(of: "→", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var bgColor: Color {
        switch style {
        case .primary: return DS.accent
        case .ghost:   return .clear
        case .dark:    return DS.bg2
        case .arena:   return DS.arena
        }
    }

    private var fgColor: Color {
        switch style {
        case .primary: return DS.accentInk
        case .ghost:   return DS.fg
        case .dark:    return DS.fg
        case .arena:   return .white
        }
    }

    private var borderColor: Color {
        switch style {
        case .ghost: return DS.line2
        default:     return .clear
        }
    }
}

/// Avatar with initials
struct DSAvatar: View {
    let name: String
    var size: CGFloat = 32
    var accent: Bool = false
    var imageData: Data? = nil

    private var initials: String {
        let parts = name.split(whereSeparator: { $0 == " " || $0 == "_" }).prefix(2)
        return parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
    }

    private var hue: Double {
        Double(name.unicodeScalars.reduce(0) { $0 + $1.value } % 360)
    }

    #if canImport(UIKit)
    private var uiImage: UIImage? {
        guard let imageData, !imageData.isEmpty else { return nil }
        return UIImage(data: imageData)
    }
    #endif

    var body: some View {
        ZStack {
            Circle()
                .fill(accent ? DS.accent : Color(hue: hue / 360, saturation: 0.5, brightness: 0.3))
            #if canImport(UIKit)
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                initialsView
            }
            #else
            initialsView
            #endif
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(DS.line, lineWidth: 1))
    }

    private var initialsView: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.bebas(size * 0.38))
            .foregroundStyle(accent ? DS.accentInk : .white)
    }
}

/// Team crest badge
struct DSCrest: View {
    let team: String
    var size: CGFloat = 40

    private static let colors: [String: Color] = [
        "LAL": Color(dsHex: "552583"),
        "BOS": Color(dsHex: "007A33"),
        "RMA": Color(dsHex: "febe10"),
        "BAR": Color(dsHex: "a50044"),
        "ATM": Color(dsHex: "cb3524"),
        "MCI": Color(dsHex: "6cabdd"),
        "ARS": Color(dsHex: "ef0107"),
        "LIV": Color(dsHex: "c8102e"),
        "GSW": Color(dsHex: "1d428a"),
        "PHI": Color(dsHex: "006bb6"),
        "BAY": Color(dsHex: "dc052d"),
        "SEV": Color(dsHex: "d6011f"),
    ]

    private static let names: [String: String] = [
        "LAL": "Los Angeles Lakers",
        "BOS": "Boston Celtics",
        "RMA": "Real Madrid",
        "BAR": "FC Barcelona",
        "ATM": "Atlético de Madrid",
        "MCI": "Manchester City",
        "ARS": "Arsenal",
        "LIV": "Liverpool",
        "GSW": "Golden State Warriors",
        "PHI": "Philadelphia 76ers",
        "BAY": "Bayern Munich",
        "SEV": "Sevilla",
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25)
                .fill(Self.colors[team] ?? DS.bg3)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            Text(team)
                .font(.bebas(size * 0.34))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Self.names[team] ?? team)
    }
}

/// Arena grid overlay
struct DSArenaGrid: View {
    var opacity: Double = 0.4
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                for x in stride(from: 0, through: size.width, by: 24) {
                    var p = Path(); p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: size.height))
                    ctx.stroke(p, with: .color(.white.opacity(0.06)), lineWidth: 1)
                }
                for y in stride(from: 0, through: size.height, by: 24) {
                    var p = Path(); p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: size.width, y: y))
                    ctx.stroke(p, with: .color(.white.opacity(0.06)), lineWidth: 1)
                }
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Sparkline drawn with Canvas
struct DSSparkline: View {
    let points: [CGFloat]
    var color: Color = DS.accent

    var body: some View {
        Canvas { ctx, size in
            guard points.count > 1 else { return }
            let mn = points.min()!, mx = points.max()!
            let range = mx - mn == 0 ? 1 : mx - mn
            let step = size.width / CGFloat(points.count - 1)

            func pt(_ i: Int) -> CGPoint {
                CGPoint(x: CGFloat(i) * step,
                        y: size.height - (points[i] - mn) / range * (size.height - 4) - 2)
            }

            // Fill area
            var fill = Path()
            fill.move(to: CGPoint(x: 0, y: size.height))
            for i in 0..<points.count { fill.addLine(to: pt(i)) }
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.closeSubpath()
            ctx.fill(fill, with: .color(color.opacity(0.18)))

            // Line
            var line = Path()
            line.move(to: pt(0))
            for i in 1..<points.count { line.addLine(to: pt(i)) }
            ctx.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.5))
        }
        .accessibilityHidden(true)
    }
}

/// Section title row (mono uppercase + optional action)
struct DSSectionRow: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .textCase(.uppercase)
                .font(.jbMono(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(DS.fg3)
            Spacer()
            if let action {
                Button(action: { onAction?() }) {
                    Text(action)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.fg2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
}

/// Betsy mark (B logo shape)
struct BetsyMark: View {
    var size: CGFloat = 22
    var color: Color = DS.accent

    var body: some View {
        Image("BetsyLogo")
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
