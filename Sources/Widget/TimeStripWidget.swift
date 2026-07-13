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

    var body: some View {
        RibbonView(
            snapshot: RibbonFixtures.fourRows,
            is12h: RibbonFormatter.uses12HourClock(locale: .current)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // center within the family bounds
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
        // Use the full family bounds (default content margins would shrink the usable
        // width below the ribbon's fixed layout and clip the last column).
        .contentMarginsDisabled()
    }
}

// NOTE: macOS does not support previewing widgets in Xcode's canvas ("This platform does
// not support previewing widgets"). Preview the ribbon itself via TimeStripUI's
// RibbonPreviews instead (canvas works from the app/framework, not this extension).
