import SwiftUI
import TimeStripKit
import TimeStripUI

// macOS cannot preview a WidgetKit widget in the canvas (verified — see the widget target).
// So we reproduce the widget faithfully from the app target: the SAME `WidgetRibbonView` the real
// widget renders, inset by WidgetKit's content margins inside a family-sized tile with the widget
// background — i.e. exactly what gets placed. `WidgetRibbonView` is responsive (fills whatever
// bounds it's given), so it fills the content area edge-to-edge just like the real widget.
//
// NOTE on size: Apple doesn't publish fixed macOS widget point sizes (the real size arrives at
// runtime), but `.systemMedium` is a wide, short tile and `.systemLarge` a ~square one; the tiles
// below are representative.
//
// Appearance follows the canvas "Color Scheme" toggle — no forced appearance here.

private struct WidgetPreview: View {
    let snapshot: RibbonSnapshot
    let is12h: Bool
    let tileSize: CGSize
    let maxRows: Int
    @Environment(\.colorScheme) private var scheme

    private static let contentMargin: CGFloat = 16   // ≈ WidgetKit's default macOS margins
    private static let tileCornerRadius: CGFloat = 20 // OS-provided at runtime; approximated

    var body: some View {
        // The locale drives 12h vs 24h (en_US → 12h, en_GB → 24h).
        WidgetRibbonView(
            snapshot: snapshot,
            locale: is12h ? Locale(identifier: "en_US") : Locale(identifier: "en_GB"),
            maxRows: maxRows
        )
        .padding(Self.contentMargin)
        .frame(width: tileSize.width, height: tileSize.height)
        .background(WidgetBackground(scheme: scheme))
        .clipShape(RoundedRectangle(cornerRadius: Self.tileCornerRadius, style: .continuous))
        .padding(40)
        .background(scheme == .dark ? Color(white: 0.11) : Color(white: 0.88))  // desktop-ish backdrop
    }
}

private let mediumTile = CGSize(width: 329, height: 155)  // ≈ macOS .systemMedium
private let largeTile = CGSize(width: 329, height: 345)   // ≈ macOS .systemLarge

#Preview("Medium · 24h") {
    WidgetPreview(snapshot: RibbonFixtures.fourRows, is12h: false, tileSize: mediumTile, maxRows: 4)
}

#Preview("Medium · 12h") {
    WidgetPreview(snapshot: RibbonFixtures.fourRows, is12h: true, tileSize: mediumTile, maxRows: 4)
}

#Preview("Large · 24h") {
    WidgetPreview(snapshot: RibbonFixtures.sevenRows, is12h: false, tileSize: largeTile, maxRows: 7)
}

#Preview("Large · 12h") {
    WidgetPreview(snapshot: RibbonFixtures.sevenRows, is12h: true, tileSize: largeTile, maxRows: 7)
}
