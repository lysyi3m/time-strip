import SwiftUI
import CoreGraphics

/// The widget's container material — a quiet surface, not a flat color. Three layers per the
/// designer spec: a broad near-invisible vertical gradient, a static ambient radial "bloom"
/// (a fixed part of the material — it never tracks the current hour or animates), and a
/// monochromatic 1px noise dither at ~1–2% via `softLight`. At viewing distance none of it
/// reads as grain; the widget just stops feeling digitally flat.
///
/// Placeholder pending final designer tokens, but structured so the tokens swap cleanly.
public struct WidgetBackground: View {
    private let scheme: ColorScheme

    public init(scheme: ColorScheme) { self.scheme = scheme }

    public var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack {
                verticalGradient
                bloom(width: w)
                noise
                    .blendMode(.softLight)
                    .opacity(scheme == .dark ? 0.016 : 0.0115)
            }
            // Very subtle inner hairline tracing the container's own rounded shape, so the widget
            // reads as carved from a single material (no visible border/divider). Falls back to a
            // rectangle outside a widget container (previews/onboarding) — still fine at this weight.
            .overlay(
                ContainerRelativeShape()
                    .strokeBorder(
                        scheme == .dark ? Color.black.opacity(0.06) : Color.white.opacity(0.05),
                        lineWidth: 0.5
                    )
            )
        }
    }

    // MARK: layers

    private var verticalGradient: some View {
        let stops: [Color] = scheme == .dark
            ? [Color(hex: 0x171824), Color(hex: 0x12131C), Color(hex: 0x0E1018)]
            : [Color(hex: 0xF7F5FA), Color(hex: 0xF3F2F7), Color(hex: 0xEEEFF5)]
        return LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
    }

    /// Off-center radial tint (lavender/indigo) fading to clear. Radius is a fraction of widget
    /// width, so it scales with the container. Fixed origin — part of the material, not dynamic.
    private func bloom(width: CGFloat) -> some View {
        let tint = scheme == .dark ? Color(hex: 0x7467B4) : Color(hex: 0xB9ACDC)
        // Dark mode spreads the bloom over a wider area at lower opacity so it reads as ambient
        // depth rather than a concentrated hotspot (designer note §6).
        let opacity = scheme == .dark ? 0.03 : 0.025
        let radiusFraction: CGFloat = scheme == .dark ? 0.95 : 0.70
        let origin = scheme == .dark ? UnitPoint(x: 0.47, y: 0.42) : UnitPoint(x: 0.42, y: 0.44)
        return RadialGradient(
            colors: [tint.opacity(opacity), tint.opacity(0)],
            center: origin,
            startRadius: 0,
            endRadius: max(1, width * radiusFraction)
        )
    }

    private var noise: some View {
        Image(decorative: WidgetBackground.noiseTile(for: scheme), scale: 1)
            .resizable(resizingMode: .tile)
    }

    // MARK: monochromatic noise tile (generated once per scheme, then cached)

    private static let lightNoise: CGImage = makeNoise(size: 160, luminance: 0.35...0.65)
    private static let darkNoise: CGImage = makeNoise(size: 160, luminance: 0.30...0.70)

    private static func noiseTile(for scheme: ColorScheme) -> CGImage {
        scheme == .dark ? darkNoise : lightNoise
    }

    /// A square grayscale tile of neutral-gray random pixels in the given luminance range. Under
    /// `softLight` at low opacity this dithers the flat gradient by ~1 level — invisible as grain.
    private static func makeNoise(size: Int, luminance: ClosedRange<Double>) -> CGImage {
        // Let CoreGraphics own the backing store (`data: nil`) and write the random bytes into
        // `ctx.data`. Passing a Swift array's inout pointer as backing storage is only valid for
        // the init call — it can dangle before `makeImage()` reads it. `bytesPerRow: 0` lets CG
        // choose an aligned stride, so we index rows by the context's actual `bytesPerRow`.
        let ctx = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        let rowBytes = ctx.bytesPerRow
        let buffer = ctx.data!.assumingMemoryBound(to: UInt8.self)
        var rng = SystemRandomNumberGenerator()
        for y in 0..<size {
            for x in 0..<size {
                buffer[y * rowBytes + x] = UInt8((Double.random(in: luminance, using: &rng) * 255).rounded())
            }
        }
        return ctx.makeImage()!
    }
}
