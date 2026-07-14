import SwiftUI
import WidgetKit
import TimeStripKit
import TimeStripUI

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

// P4: still a static placeholder provider driven by a hardcoded fixture. The real
// hourly timeline provider lands in P5.
struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: Date())], policy: .never))
    }
}

struct TimeStripWidgetEntryView: View {
    var entry: PlaceholderEntry
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        WidgetRibbonView(
            snapshot: RibbonFixtures.fiveRows,
            is12h: RibbonFormatter.uses12HourClock(locale: .current)
        )
        // Required since macOS 14: declare the widget's background via `.containerBackground`
        // so WidgetKit composits it (and can offer background removal in some contexts).
        .containerBackground(for: .widget) { WidgetBackground(scheme: scheme) }
    }
}

struct TimeStripWidget: Widget {
    let kind = "TimeStripWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { entry in
            TimeStripWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Time Strip")
        .description("Time zones as day/night ribbons.")
        .supportedFamilies([.systemExtraLarge])
        // Keep WidgetKit's standard content margins (~16pt, HIG): the content is sized to fit
        // within them and scales to fit, so it no longer needs to claim the full bounds.
    }
}

// NOTE: the widget itself CANNOT be previewed in Xcode's canvas on macOS. Verified with the
// modern `#Preview("…", as: .systemExtraLarge)` macro (Xcode 17F113 / macOS 26.5): the canvas
// fails with "This platform does not support previewing widgets — No plugin is registered to
// launch the process type widgetExtension." It's the widgetExtension process type macOS won't
// launch for previews, so no API avoids it. Preview the widget's content view instead —
// TimeStripUI's RibbonView, via the app target's RibbonPreviews.
