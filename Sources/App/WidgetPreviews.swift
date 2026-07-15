import SwiftUI
import TimeStripKit
import TimeStripUI

// macOS cannot preview a WidgetKit widget in the canvas (verified — see the widget target).
// So we reproduce the widget faithfully from the app target: the SAME `WidgetRibbonView` the
// real widget renders, inside a representative `.systemExtraLarge` tile with the widget
// background and rounded corners, on a contrasting backdrop.
//
// NOTE on size: Apple does not publish a fixed macOS widget point size — `.systemExtraLarge`
// varies by device and can be portrait or landscape; the real size arrives at runtime via
// `TimelineProviderContext.displaySize`. `widgetSize` below is the spec's ~726×354 pt
// approximation, only for the preview tile. Because `WidgetRibbonView` scales to fit its
// bounds, the content stays correct (never clips) whatever the real size turns out to be.
//
// Appearance follows the canvas "Color Scheme" toggle — no forced appearance here.

private struct WidgetPreview: View {
    let snapshot: RibbonSnapshot
    let is12h: Bool
    @Environment(\.colorScheme) private var scheme

    private static let widgetSize = CGSize(width: 726, height: 354)  // ≈ macOS extra-large (spec §3)
    private static let tileCornerRadius: CGFloat = 28                // OS-provided at runtime; approximated here

    var body: some View {
        // The locale drives 12h vs 24h (en_US → 12h, en_GB → 24h), which is what these two
        // previews demonstrate.
        WidgetRibbonView(
            snapshot: snapshot,
            locale: is12h ? Locale(identifier: "en_US") : Locale(identifier: "en_GB")
        )
        .frame(width: Self.widgetSize.width, height: Self.widgetSize.height)
        .background(WidgetBackground(scheme: scheme))
        .clipShape(RoundedRectangle(cornerRadius: Self.tileCornerRadius, style: .continuous))
        .padding(40)
        .background(scheme == .dark ? Color(white: 0.11) : Color(white: 0.88))  // desktop-ish backdrop
    }
}

#Preview("Widget · 24h") {
    WidgetPreview(snapshot: RibbonFixtures.fiveRows, is12h: false)
}

#Preview("Widget · 12h") {
    WidgetPreview(snapshot: RibbonFixtures.fiveRows, is12h: true)
}
