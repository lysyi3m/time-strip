import SwiftUI
import WidgetKit
import TimeStripKit
import TimeStripUI

/// One hourly timeline entry: the instant it becomes current plus its fully-resolved snapshot.
/// The snapshot already carries resolved local times; the view formats labels with `.current`.
/// `is12h` is captured at bake time so every entry renders consistently.
struct RibbonEntry: TimelineEntry {
    let date: Date
    let snapshot: RibbonSnapshot
    let is12h: Bool
}

// P6: an intent-driven provider. Rows come from the user's Edit-Widget selection (resolved by
// `TimeStripConfigurationIntent`), falling back to `CityCatalog.defaults` when unconfigured.
struct RibbonTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RibbonEntry {
        entry(for: CityCatalog.defaults, at: Date())
    }

    func snapshot(for configuration: TimeStripConfigurationIntent, in context: Context) async -> RibbonEntry {
        entry(for: configuration.resolvedCities, at: Date())
    }

    func timeline(for configuration: TimeStripConfigurationIntent, in context: Context) async -> Timeline<RibbonEntry> {
        let is12h = RibbonFormatter.uses12HourClock(locale: .current)
        let entries = RibbonEngine
            .hourlySnapshots(now: Date(), cities: configuration.resolvedCities)
            .map { RibbonEntry(date: $0.now, snapshot: $0, is12h: is12h) }
        // `.atEnd`: WidgetKit reloads once the last (≈24h-out) entry is reached — roughly one
        // scheduled reload per day. Hourly entries suffice because content only changes on the
        // hour (the now-frame is fixed), so all 24 come from this single call.
        return Timeline(entries: entries, policy: .atEnd)
    }

    /// A single representative entry built through the real engine at `date`, so the gallery
    /// placeholder/snapshot matches live rendering.
    private func entry(for cities: [City], at date: Date) -> RibbonEntry {
        RibbonEntry(
            date: date,
            snapshot: RibbonEngine.snapshot(now: date, cities: cities),
            is12h: RibbonFormatter.uses12HourClock(locale: .current)
        )
    }
}

struct TimeStripWidgetEntryView: View {
    var entry: RibbonEntry
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        WidgetRibbonView(snapshot: entry.snapshot, is12h: entry.is12h)
            // Required since macOS 14: declare the widget's background via `.containerBackground`
            // so WidgetKit composits it (and can offer background removal in some contexts).
            .containerBackground(for: .widget) { WidgetBackground(scheme: scheme) }
    }
}

struct TimeStripWidget: Widget {
    let kind = "TimeStripWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TimeStripConfigurationIntent.self,
            provider: RibbonTimelineProvider()
        ) { entry in
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
// TimeStripUI's WidgetRibbonView, via the app target's WidgetPreviews.
