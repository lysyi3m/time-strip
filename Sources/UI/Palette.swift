import SwiftUI

/// Continuous wall-clock color ramp + UI tokens. Iterating — placeholders, not frozen.
///
/// Time of day reads through a smooth *intensity* (brightness) curve on a warm/cool hue: deep
/// cool night → purple dawn → bright near-neutral day (peak ≈ noon) → warm amber dusk → back
/// to night. The color is a **continuous** function of the local clock hour (interpolated
/// between control points), so every column differs slightly and a row reads as one smooth
/// gradient — not flat per-band blocks. Brightness tracks time-of-day, so shading survives
/// desaturation / tinted rendering (spec §6.6).
enum Palette {

    private struct Ramp { let points: [(hour: Double, rgb: RGB)] }

    // Light ("One Row Anatomy" proposal): subtle, premium, calm — calm indigo night rising
    // through cool lavender dawn to warm ivory day (not yellow), then cozy amber dusk back to
    // indigo. Softer/lighter than dark mode: night stays light enough that numbers read dark
    // throughout (matching the light theme). Anchors: night #5E6EA8, dawn #C3B7DF,
    // day #F9F2DE, dusk #E3A76E.
    private static let lightRamp = Ramp(points: [
        (0,  RGB(hex: 0x8C97C6)),  // night — calm indigo
        (3,  RGB(hex: 0xC1BDE0)),  // night lifting
        (6,  RGB(hex: 0xE1DAED)),  // dawn — cool lavender
        (8,  RGB(hex: 0xF2EEEE)),  // dawn → day
        (11, RGB(hex: 0xFBF5EA)),  // day peak — warm ivory
        (16, RGB(hex: 0xFAF1E0)),  // day, warming
        (18, RGB(hex: 0xF3CE9A)),  // dusk — cozy amber
        (20, RGB(hex: 0xEDBE92)),  // dusk — amber
        (22, RGB(hex: 0xCFB4BC)),  // fading mauve
        (23, RGB(hex: 0xB1A9C5)),  // toward night
        (24, RGB(hex: 0x8C97C6)),  // night (== hour 0)
    ])

    // Dark ("Option D" intensity): deep blue-purple night rising to a near-white day, warm
    // amber dusk, back to night. Wide brightness range — daytime glows, night recedes.
    private static let darkRamp = Ramp(points: [
        (0,  RGB(hex: 0x191E38)),  // deep night
        (6,  RGB(hex: 0x554D80)),  // dawn — purple
        (8,  RGB(hex: 0xB4ADC8)),  // light rising — lavender
        (11, RGB(hex: 0xE9E2D6)),  // day peak — near-white warm neutral
        (13, RGB(hex: 0xEADFCC)),  // warming
        (16, RGB(hex: 0xE0B57F)),  // amber
        (18, RGB(hex: 0xC9884F)),  // dusk — deep amber
        (20, RGB(hex: 0x5E4038)),  // dark warm
        (22, RGB(hex: 0x2A2444)),  // near night
        (24, RGB(hex: 0x191E38)),  // deep night (== hour 0)
    ])

    /// Interpolated color for a continuous local clock hour (0..<24; wraps at 24).
    static func rgb(forHour hour: Double, _ scheme: ColorScheme) -> RGB {
        let points = (scheme == .dark ? darkRamp : lightRamp).points
        let wrapped = hour.truncatingRemainder(dividingBy: 24)
        let h = wrapped < 0 ? wrapped + 24 : wrapped
        for i in 1..<points.count where h <= points[i].hour {
            let lo = points[i - 1], hi = points[i]
            let t = (h - lo.hour) / (hi.hour - lo.hour)
            return lo.rgb.lerp(to: hi.rgb, t: t)
        }
        return points.last!.rgb
    }

    static func color(forHour hour: Double, _ scheme: ColorScheme) -> Color {
        rgb(forHour: hour, scheme).color
    }

    /// Number color chosen for contrast against the cell's own luminance, so it stays legible
    /// over both bright (day) and dark (night) cells — flips automatically along the ramp.
    static func number(forHour hour: Double, _ scheme: ColorScheme) -> Color {
        let bg = rgb(forHour: hour, scheme)
        let luminance = 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b
        return luminance > 0.5 ? Color(hex: 0x1D1D1F) : Color(hex: 0xF4F6FB)
    }

    /// Rail text (city name / zone), on the widget background rather than a gradient.
    static func railLabel(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xFFFFFF) : Color(hex: 0x1D1D1F)
    }

    // MARK: now-indicator "frosted glass" tokens
    //
    // The NOW marker is a translucent glass slab, not a stroke: a milky fill, a recessed inner
    // shadow, and a top-lit rim highlight. Placeholders — tuned by eye over the ribbons.

    /// Milky translucent fill — lightens the current column like frosted acrylic. Kept within the
    /// designer's 10–15% so it doesn't wash out the now-column numbers underneath (the most
    /// important ones); the glass reads mostly from its rim highlight + inner shadow.
    static func nowGlassFill(_ scheme: ColorScheme) -> Color {
        Color.white.opacity(scheme == .dark ? 0.12 : 0.15)
    }

    /// Inner shadow that recesses the glass slightly into the surface for depth.
    static func nowGlassInnerShadow(_ scheme: ColorScheme) -> Color {
        Color.black.opacity(scheme == .dark ? 0.28 : 0.18)
    }

    /// Crisp near-white rim tracing the whole capsule — brightest at the top, but still clearly
    /// present down the sides and along the bottom so the marker reads on any ribbon behind it.
    static func nowGlassRim(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.95), .white.opacity(0.55)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// sRGB triple in 0...1 for gradient interpolation.
struct RGB {
    let r, g, b: Double

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    init(hex: UInt) {
        self.init(
            r: Double((hex >> 16) & 0xFF) / 255,
            g: Double((hex >> 8) & 0xFF) / 255,
            b: Double(hex & 0xFF) / 255
        )
    }

    func lerp(to other: RGB, t: Double) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
}

public extension Color {
    /// A color from a 24-bit `0xRRGGBB` literal, in sRGB. Public so the app target can share the
    /// same helper instead of redefining it.
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
