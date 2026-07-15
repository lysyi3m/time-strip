import SwiftUI
import WidgetKit
import TimeStripKit
import TimeStripUI

/// One timeline entry. Either a ribbon (the instant it becomes current + its resolved snapshot;
/// `is12h` captured at bake time so every entry renders consistently) or a setup prompt when the
/// widget has fewer than two cities configured.
struct RibbonEntry: TimelineEntry {
    let date: Date
    let content: Content

    enum Content {
        case ribbon(RibbonSnapshot, is12h: Bool)
        case setupNeeded
    }
}

// P6: an intent-driven provider. Rows come from the user's Edit-Widget selection (resolved by
// `TimeStripConfigurationIntent`), falling back to `CityCatalog.defaults` when unconfigured.
struct RibbonTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RibbonEntry {
        entry(for: CityCatalog.defaults, at: Date())
    }

    func snapshot(for configuration: TimeStripConfigurationIntent, in context: Context) async -> RibbonEntry {
        rows(for: configuration).map { entry(for: $0, at: Date()) }
            ?? RibbonEntry(date: Date(), content: .setupNeeded)
    }

    func timeline(for configuration: TimeStripConfigurationIntent, in context: Context) async -> Timeline<RibbonEntry> {
        guard let cities = rows(for: configuration) else {
            // Fewer than two cities: a single static setup-prompt entry, no reloads needed.
            return Timeline(entries: [RibbonEntry(date: Date(), content: .setupNeeded)], policy: .never)
        }
        let is12h = RibbonFormatter.uses12HourClock(locale: .current)
        let entries = RibbonEngine
            .hourlySnapshots(now: Date(), cities: cities)
            .map { RibbonEntry(date: $0.now, content: .ribbon($0, is12h: is12h)) }
        // `.atEnd`: WidgetKit reloads once the last (≈24h-out) entry is reached — roughly one
        // scheduled reload per day. Hourly entries suffice because content only changes on the
        // hour (the now-frame is fixed), so all 24 come from this single call.
        return Timeline(entries: entries, policy: .atEnd)
    }

    /// The cities to render, or `nil` when the setup prompt should show. A fresh widget (nothing
    /// configured) falls back to a sensible default set; exactly one city is too few to compare,
    /// so it prompts; two or more render as chosen.
    private func rows(for configuration: TimeStripConfigurationIntent) -> [City]? {
        let configured = configuration.configuredCities
        switch configured.count {
        case 0: return CityCatalog.defaults
        case 1: return nil
        default: return configured
        }
    }

    /// A single representative ribbon entry built through the real engine at `date`, so the
    /// gallery placeholder/snapshot matches live rendering.
    private func entry(for cities: [City], at date: Date) -> RibbonEntry {
        RibbonEntry(
            date: date,
            content: .ribbon(
                RibbonEngine.snapshot(now: date, cities: cities),
                is12h: RibbonFormatter.uses12HourClock(locale: .current)
            )
        )
    }
}

struct TimeStripWidgetEntryView: View {
    var entry: RibbonEntry
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        content
            // Required since macOS 14: declare the widget's background via `.containerBackground`
            // so WidgetKit composits it (and can offer background removal in some contexts).
            .containerBackground(for: .widget) { WidgetBackground(scheme: scheme) }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.content {
        case let .ribbon(snapshot, is12h):
            WidgetRibbonView(snapshot: snapshot, is12h: is12h)
        case .setupNeeded:
            WidgetPromptView()
        }
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
