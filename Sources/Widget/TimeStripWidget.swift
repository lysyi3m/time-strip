import SwiftUI
import WidgetKit

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

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
        Text("Time Strip")
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
    }
}
