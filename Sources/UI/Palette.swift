import SwiftUI
import TimeStripKit

/// Solar color ramp for the gradient row shading, plus UI tokens. Iterating — these are
/// the current agreed placeholders, not frozen.
///
/// The ramp maps sun elevation → color and is **directional**: at the same low elevation a
/// *rising* sun tints cool violet (dawn) while a *setting* sun tints warm orange (dusk),
/// per the golden-hour reference. Colors are lightness-ordered (day lightest → deep night
/// darkest) in both appearances, so shading survives desaturation / tinted rendering.
enum Palette {

    // Vivid ramp anchors. Light stays appropriately light; dark stays dark, with the
    // dawn/dusk tints saturated enough to read.
    private struct Anchors {
        let day, dawn, dusk, night, deep: RGB
    }

    private static let light = Anchors(
        day:   RGB(hex: 0xFCE7B3),  // warm gold
        dawn:  RGB(hex: 0xAEA0E0),  // cool violet
        dusk:  RGB(hex: 0xF2A055),  // warm orange
        night: RGB(hex: 0x8698D8),  // periwinkle
        deep:  RGB(hex: 0x47589C)   // deep blue
    )

    // Tuned so relative luminance is strictly monotonic deep < night < dawn/dusk < day
    // (day is the lightest anchor), keeping the violet/amber hues — required for
    // desaturation-safe shading (spec §6.6).
    private static let dark = Anchors(
        day:   RGB(hex: 0x4C5461),  // lightest
        dawn:  RGB(hex: 0x433A63),  // cool violet, below day
        dusk:  RGB(hex: 0x5C4531),  // warm amber, below day
        night: RGB(hex: 0x202A45),
        deep:  RGB(hex: 0x12172A)   // darkest
    )

    /// Elevation control points (degrees, color), low → high. The mid "golden" anchor is
    /// direction-dependent (dawn vs dusk).
    private static func stops(rising: Bool, _ scheme: ColorScheme) -> [(elevation: Double, rgb: RGB)] {
        let a = scheme == .dark ? dark : light
        return [
            (-14, a.deep),
            (-6,  a.night),
            (0,   rising ? a.dawn : a.dusk),  // golden/blue hour tint
            (8,   a.day),
        ]
    }

    /// Interpolated sRGB color for a given elevation + sun direction.
    static func rgb(forElevation elevation: Double, rising: Bool, _ scheme: ColorScheme) -> RGB {
        let points = stops(rising: rising, scheme)
        if elevation <= points.first!.elevation { return points.first!.rgb }
        if elevation >= points.last!.elevation { return points.last!.rgb }
        for i in 1..<points.count where elevation < points[i].elevation {
            let lo = points[i - 1], hi = points[i]
            let t = (elevation - lo.elevation) / (hi.elevation - lo.elevation)
            return lo.rgb.lerp(to: hi.rgb, t: t)
        }
        return points.last!.rgb
    }

    static func color(forElevation elevation: Double, rising: Bool, _ scheme: ColorScheme) -> Color {
        rgb(forElevation: elevation, rising: rising, scheme).color
    }

    /// Number color chosen for contrast against the slot's own background luminance, so it
    /// stays legible over both bright day and dark night cells.
    static func number(onElevation elevation: Double, rising: Bool, _ scheme: ColorScheme) -> Color {
        let bg = rgb(forElevation: elevation, rising: rising, scheme)
        let luminance = 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b
        return luminance > 0.5 ? Color(hex: 0x1D1D1F) : Color(hex: 0xF4F6FB)
    }

    /// Rail text (city name / zone), on the widget background rather than a gradient.
    static func railLabel(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xFFFFFF) : Color(hex: 0x1D1D1F)
    }

    static func nowFrame(_ scheme: ColorScheme) -> Color {
        (scheme == .dark ? Color(hex: 0xFFFFFF) : Color(hex: 0x1D1D1F)).opacity(0.8)
    }

    /// Faint vertical tick marking a day boundary.
    static func boundaryTick(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x4B4C52) : Color(hex: 0xE5E7EB)
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

extension Color {
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
