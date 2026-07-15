import SwiftUI
import TimeStripKit

/// The widget's full content — the ribbon fit into the family bounds. This is exactly what the
/// real `TimeStripWidget` renders *and* what the app-target preview renders, so the two cannot
/// drift. The background is supplied by the surrounding context: the widget applies it via
/// `.containerBackground`, the preview as a matching backdrop — both use `WidgetBackground`,
/// so they stay identical.
///
/// Per Apple's guidance, widget point sizes vary by device/platform (macOS `.systemExtraLarge`
/// has no fixed size and can be portrait or landscape), and the real size is only known at
/// runtime. So the fixed-layout ribbon is **scaled to fit** the container it's given rather
/// than assuming specific bounds — it never clips, and centers within whatever space it has.
public struct WidgetRibbonView: View {
    private let snapshot: RibbonSnapshot
    private let locale: Locale

    public init(snapshot: RibbonSnapshot, locale: Locale = .current) {
        self.snapshot = snapshot
        self.locale = locale
    }

    public var body: some View {
        GeometryReader { proxy in
            let ideal = RibbonView.idealSize(for: snapshot)
            let scale = min(
                proxy.size.width / ideal.width,
                proxy.size.height / ideal.height,
                1  // never upscale past the designed size
            )
            RibbonView(snapshot: snapshot, locale: locale)
                .frame(width: ideal.width, height: ideal.height)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)  // center
        }
        // Collapse the grid of per-cell text into one spoken summary of current times.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(RibbonFormatter.accessibilitySummary(for: snapshot, locale: locale))
    }
}
