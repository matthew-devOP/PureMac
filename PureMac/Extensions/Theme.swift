import SwiftUI

// MARK: - Color Theme

extension Color {
    // Background colors
    static let pmBackground = Color(hex: "0f0f1a")
    static let pmSidebar = Color(hex: "161627")
    static let pmCard = Color(hex: "1c1c35")
    static let pmCardHover = Color(hex: "252545")

    // Accent colors
    static let pmAccent = Color(hex: "6366f1")
    static let pmAccentLight = Color(hex: "818cf8")
    static let pmAccentDark = Color(hex: "4f46e5")

    // Gradient colors
    static let pmGradientStart = Color(hex: "6366f1")
    static let pmGradientEnd = Color(hex: "a855f7")
    static let pmGradientAlt = Color(hex: "ec4899")

    // Status colors
    static let pmSuccess = Color(hex: "10b981")
    static let pmWarning = Color(hex: "f59e0b")
    static let pmDanger = Color(hex: "ef4444")
    static let pmInfo = Color(hex: "3b82f6")

    // Text colors
    static let pmTextPrimary = Color(hex: "f1f5f9")
    static let pmTextSecondary = Color(hex: "94a3b8")
    static let pmTextMuted = Color(hex: "64748b")

    // Separator
    static let pmSeparator = Color(hex: "2d2d50")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Gradients

struct AppGradients {
    static let primary = LinearGradient(
        colors: [.pmGradientStart, .pmGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accent = LinearGradient(
        colors: [.pmAccent, .pmGradientEnd],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let danger = LinearGradient(
        colors: [.pmDanger, Color(hex: "dc2626")],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let success = LinearGradient(
        colors: [.pmSuccess, Color(hex: "059669")],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let background = LinearGradient(
        colors: [Color(hex: "0f0f1a"), Color(hex: "1a1a2e")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let sidebar = LinearGradient(
        colors: [Color(hex: "131325"), Color(hex: "1a1a35")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let scanRing = AngularGradient(
        colors: [.pmGradientStart, .pmGradientEnd, .pmGradientAlt, .pmGradientStart],
        center: .center
    )
}

// MARK: - Shadows

extension View {
    func pmShadow(radius: CGFloat = 10, y: CGFloat = 4) -> some View {
        self.shadow(color: .black.opacity(0.3), radius: radius, x: 0, y: y)
    }

    func pmGlow(color: Color = .pmAccent, radius: CGFloat = 20) -> some View {
        self.shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 0)
    }
}

// MARK: - Text Styles

extension Font {
    static let pmTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let pmHeadline = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let pmSubheadline = Font.system(size: 16, weight: .medium, design: .rounded)
    static let pmBody = Font.system(size: 14, weight: .regular, design: .rounded)
    static let pmCaption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let pmLargeNumber = Font.system(size: 42, weight: .bold, design: .rounded)
    static let pmMediumNumber = Font.system(size: 24, weight: .bold, design: .rounded)
}

// MARK: - Animation

extension Animation {
    static let pmSpring = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    static let pmSmooth = Animation.easeInOut(duration: 0.3)
    static let pmSlow = Animation.easeInOut(duration: 0.6)
}
