import SwiftUI

// MARK: - Theme  (Stadium dark · Electric-lime accent)

struct Theme {

    // MARK: Spacing scale
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let sm:  CGFloat = 12
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 20
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Border-radius scale
    enum Radius {
        static let control: CGFloat = 12
        static let card:    CGFloat = 16
        static let panel:   CGFloat = 20
        static let sheet:   CGFloat = 24
    }

    static func radius(_ requested: CGFloat) -> CGFloat { requested }

    // MARK: Typography scale
    enum Typography {
        static let eyebrow      = Font.system(size: 11, weight: .black)
        static let sectionTitle = Font.system(size: 12, weight: .black)
        static let button       = Font.system(size: 14, weight: .black)
        static let body         = Font.system(size: 15, weight: .medium)
        static let statValue    = Font.system(size: 30, weight: .black)
        static let screenTitle  = Font.system(size: 28, weight: .black)
    }

    // MARK: Core palette
    static let bg         = Color(red: 0.039, green: 0.039, blue: 0.043)
    static let paper      = Color(red: 0.973, green: 0.969, blue: 0.957)
    static let surface    = Color(red: 0.078, green: 0.078, blue: 0.094)
    static let surfaceAlt = Color(red: 0.110, green: 0.110, blue: 0.141)
    static let card       = Color(red: 0.078, green: 0.078, blue: 0.094)
    static let cardAlt    = Color(red: 0.110, green: 0.110, blue: 0.141)
    static let border     = Color.white.opacity(0.18)
    static let paperLine  = Color.white.opacity(0.18)
    static let glassBorder = Color.white.opacity(0.12)

    // MARK: Ink (text on dark backgrounds)
    static let ink          = Color(red: 0.941, green: 0.937, blue: 0.953)
    static let inkSecondary = Color(red: 0.941, green: 0.937, blue: 0.953).opacity(0.68)
    static let inkTertiary  = Color(red: 0.941, green: 0.937, blue: 0.953).opacity(0.52)
    static let textMain     = Color(red: 0.941, green: 0.937, blue: 0.953)
    static let textSecondary = Color(red: 0.941, green: 0.937, blue: 0.953).opacity(0.68)

    // MARK: Accent — Electric lime (#d4ff3a)
    static let accent     = Color(red: 0.831, green: 1.000, blue: 0.227)
    static let accentInk  = Color(red: 0.039, green: 0.039, blue: 0.043)
    static let accentSoft = Color(red: 0.831, green: 1.000, blue: 0.227).opacity(0.16)
    static let accentLine = Color(red: 0.831, green: 1.000, blue: 0.227).opacity(0.32)

    // MARK: Named accents
    static let hot       = Color(red: 0.96, green: 0.22, blue: 0.42)
    static let electric  = Color(red: 0.34, green: 0.48, blue: 0.98)
    static let lime      = Color(red: 0.42, green: 0.86, blue: 0.28)
    static let sun       = Color(red: 1.00, green: 0.78, blue: 0.20)
    static let violetPop = Color(red: 0.56, green: 0.22, blue: 0.85)
    static let skyPop    = Color(red: 0.16, green: 0.74, blue: 0.96)

    // Legacy aliases
    static let cyan      = Color(red: 0.16, green: 0.74, blue: 0.96)
    static let violet    = Color(red: 0.56, green: 0.22, blue: 0.85)
    static let arena     = hot
    static let gold      = sun
    static let champagne = Color(red: 0.82, green: 0.82, blue: 0.84)
    static let success   = lime
    static let warning   = sun
    static let silver    = Color(red: 0.72, green: 0.72, blue: 0.74)
    static let bronze    = Color(red: 0.55, green: 0.55, blue: 0.57)

    // MARK: Gradients
    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.34, green: 0.48, blue: 0.98), Color(red: 0.56, green: 0.22, blue: 0.85)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let arenaGradient = LinearGradient(
        colors: [Color(red: 0.96, green: 0.22, blue: 0.42), Color(red: 1.00, green: 0.46, blue: 0.20)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let winGradient = LinearGradient(
        colors: [Color(red: 0.42, green: 0.86, blue: 0.28), Color(red: 0.16, green: 0.74, blue: 0.56)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let sunGradient = LinearGradient(
        colors: [Color(red: 1.00, green: 0.78, blue: 0.20), Color(red: 0.96, green: 0.46, blue: 0.20)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let limeGradient = LinearGradient(
        colors: [Color(red: 0.831, green: 1.000, blue: 0.227), Color(red: 0.42, green: 0.86, blue: 0.28)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static var mainBackground: some View { BetsyBackground() }
}

// MARK: - View extension

extension View {
    func glassSurface(
        radius: CGFloat = 24,
        tint: Color = Theme.card.opacity(0.62),
        border: Color = Theme.glassBorder
    ) -> some View {
        let r = Theme.radius(radius)
        return self
            .background(RoundedRectangle(cornerRadius: r, style: .continuous).fill(tint))
            .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).stroke(border, lineWidth: 1))
    }
}
