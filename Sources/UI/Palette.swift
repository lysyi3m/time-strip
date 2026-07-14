import SwiftUI
import TimeStripKit

/// Wall-clock day bands + UI tokens. Iterating — these are the current agreed placeholders,
/// not frozen.
///
/// Coloring is deliberately simple and utilitarian: each slot's *local clock hour* maps to
/// one of four bands (night / dawn / day / dusk), and the row is a gradient between adjacent
/// column band colors so transitions read smoothly without any solar computation. Colors are
/// lightness-ordered (night darkest → day lightest, twilights between) in both appearances,
/// so shading survives desaturation / tinted rendering (spec §6.6).
enum Palette {

    /// Coarse time-of-day band, by local clock hour.
    enum Band { case night, dawn, day, dusk }

    /// Fixed wall-clock band boundaries:
    /// night 22–05 · dawn 06–07 · day 08–17 · dusk 18–21.
    static func band(forHour hour: Int) -> Band {
        switch hour {
        case 6, 7:    return .dawn
        case 8...17:  return .day
        case 18...21: return .dusk
        default:      return .night  // 0–5, 22–23
        }
    }

    private struct Bands {
        let night, dawn, day, dusk: RGB
    }

    private static let light = Bands(
        night: RGB(hex: 0x4A5CA0),  // indigo
        dawn:  RGB(hex: 0xB8A6E0),  // soft violet
        day:   RGB(hex: 0xFCE7B3),  // warm cream
        dusk:  RGB(hex: 0xF2A055)   // orange
    )

    // Warm, higher-contrast dark bands: a warm gold-taupe day lifts clearly off the navy
    // night, with a violet dawn / amber dusk between. Relative luminance is monotonic
    // night < dawn < dusk < day.
    private static let dark = Bands(
        night: RGB(hex: 0x1B2848),  // navy, darkest
        dawn:  RGB(hex: 0x453C6B),  // cool violet
        day:   RGB(hex: 0x7C7358),  // warm gold-taupe, lightest
        dusk:  RGB(hex: 0x6B472C)   // warm amber
    )

    static func rgb(for band: Band, _ scheme: ColorScheme) -> RGB {
        let b = scheme == .dark ? dark : light
        switch band {
        case .night: return b.night
        case .dawn:  return b.dawn
        case .day:   return b.day
        case .dusk:  return b.dusk
        }
    }

    static func color(forHour hour: Int, _ scheme: ColorScheme) -> Color {
        rgb(for: band(forHour: hour), scheme).color
    }

    /// Number color chosen for contrast against the slot's own band luminance, so it stays
    /// legible over both bright day and dark night cells.
    static func number(forHour hour: Int, _ scheme: ColorScheme) -> Color {
        let bg = rgb(for: band(forHour: hour), scheme)
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
