import SwiftUI
import WidgetKit
import TimeStripKit
import TimeStripUI

/// One timeline entry: either a ribbon (the instant it becomes current + its resolved snapshot)
/// or a setup prompt when the widget has fewer than two distinct cities configured. 12h/24h is
/// not stored — the view derives it from the render-time locale (see `RibbonView`).
struct RibbonEntry: TimelineEntry {
    let date: Date
    let content: Content

    enum Content {
        case ribbon(RibbonSnapshot)
        case setupNeeded
    }
}

// An intent-driven provider. Rows come from the user's Edit-Widget selection, resolved by
// `RibbonRows.resolve` (dedupe by zone; 0 → defaults, 1 → prompt, 2+ → chosen).
struct RibbonTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RibbonEntry {
        RibbonEntry(date: Date(), content: .ribbon(RibbonEngine.snapshot(now: Date(), cities: CityCatalog.defaults)))
    }

    func snapshot(for configuration: TimeStripConfigurationIntent, in context: Context) async -> RibbonEntry {
        switch resolution(for: configuration) {
        case let .ribbon(cities):
            return RibbonEntry(date: Date(), content: .ribbon(RibbonEngine.snapshot(now: Date(), cities: cities)))
        case .setupNeeded:
            return RibbonEntry(date: Date(), content: .setupNeeded)
        }
    }

    func timeline(for configuration: TimeStripConfigurationIntent, in context: Context) async -> Timeline<RibbonEntry> {
        switch resolution(for: configuration) {
        case .setupNeeded:
            // Fewer than two distinct cities: a single static setup-prompt entry, no reloads.
            return Timeline(entries: [RibbonEntry(date: Date(), content: .setupNeeded)], policy: .never)
        case let .ribbon(cities):
            let entries = RibbonEngine
                .hourlySnapshots(now: Date(), cities: cities)
                .map { RibbonEntry(date: $0.now, content: .ribbon($0)) }
            // `.atEnd`: WidgetKit reloads once the last (≈24h-out) entry is reached — roughly one
            // scheduled reload per day. Hourly entries suffice because content only changes on the
            // hour (the now-frame is fixed), so all 24 come from this single call.
            return Timeline(entries: entries, policy: .atEnd)
        }
    }

    private func resolution(for configuration: TimeStripConfigurationIntent) -> RibbonRows.Resolution {
        RibbonRows.resolve(configured: configuration.configuredCities, defaults: CityCatalog.defaults)
    }
}

struct TimeStripWidgetEntryView: View {
    var entry: RibbonEntry
    @Environment(\.colorScheme) private var scheme
    // The render-time locale WidgetKit provides — the ribbon derives 12h/24h from it, so a
    // system region / clock-format change is reflected without waiting for a fresh timeline.
    @Environment(\.locale) private var locale
    // The family the widget was placed at — determines how many rows fit.
    @Environment(\.widgetFamily) private var family

    /// Rows the current family renders: the tall `.systemLarge` fits more cities than the short
    /// `.systemMedium`. One snapshot is baked with all configured cities and trimmed to fit.
    private var maxRows: Int { family == .systemLarge ? 7 : 4 }

    var body: some View {
        content
            // Required since macOS 14: declare the widget's background via `.containerBackground`
            // so WidgetKit composits it (and can offer background removal in some contexts).
            .containerBackground(for: .widget) { WidgetBackground(scheme: scheme) }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.content {
        case let .ribbon(snapshot):
            WidgetRibbonView(snapshot: snapshot, locale: locale, maxRows: maxRows)
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
        .supportedFamilies([.systemMedium, .systemLarge])
        // Keep WidgetKit's standard content margins (~16pt, HIG): the content is sized to fit
        // within them and scales to fit, so it does not need to claim the full bounds.
    }
}

// NOTE: the widget itself CANNOT be previewed in Xcode's canvas on macOS. Verified with the
// modern `#Preview("…", as: .systemMedium)` macro (Xcode 27.0 / macOS 26.7): the canvas
// fails with "This platform does not support previewing widgets — No plugin is registered to
// launch the process type widgetExtension." It's the widgetExtension process type macOS won't
// launch for previews, so no API avoids it. Preview the widget's content view instead —
// TimeStripUI's WidgetRibbonView, via the app target's WidgetPreviews.
