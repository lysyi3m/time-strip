import SwiftUI
import TimeStripKit

/// The widget's full content — the ribbon filling the family bounds. This is exactly what the real
/// `TimeStripWidget` renders *and* what the app-target preview renders, so the two cannot drift.
/// The background is supplied by the surrounding context (the widget via `.containerBackground`,
/// the preview as a matching backdrop), both from `WidgetBackground`, so they stay identical.
///
/// `maxRows` is the family's row cap (fewer for `.systemMedium`, more for `.systemLarge`): one
/// baked snapshot can carry more cities than a given family shows, so it's trimmed here. The
/// underlying `RibbonView` is responsive — it fills whatever bounds it's given.
public struct WidgetRibbonView: View {
    private let snapshot: RibbonSnapshot
    private let locale: Locale
    private let maxRows: Int

    public init(snapshot: RibbonSnapshot, locale: Locale = .current, maxRows: Int) {
        self.snapshot = snapshot
        self.locale = locale
        self.maxRows = maxRows
    }

    public var body: some View {
        let shown = snapshot.trimmedToRows(maxRows)
        RibbonView(snapshot: shown, locale: locale)
            // Collapse the grid of per-cell text into one spoken summary of current times.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(RibbonFormatter.accessibilitySummary(for: shown, locale: locale))
    }
}
