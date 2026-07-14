import Foundation

/// Turns `(now, cities, window)` into a fully-resolved structural snapshot: a shared
/// absolute-time column grid, per-city rows, per-slot local time, and day-boundary flags.
///
/// The grid steps by a fixed 3600 s (not "add one clock hour"), so every column is one
/// absolute instant shared across all rows — the absolute-time-alignment invariant. Each
/// slot's `period` is filled by the injected `SolarClassifier` from the slot's absolute
/// instant and the city's coordinate.
public enum RibbonEngine {
    public static func snapshot(
        now: Date,
        cities: [City],
        window: WindowSpec = .init(),
        referenceIndex: Int = 0,
        classifier: SolarClassifier = .init()
    ) -> RibbonSnapshot {
        let columnCount = window.columnCount

        // Floor `now` to the start of its hour in the reference zone, then step by a fixed
        // 3600 s. Falling back to .gmt keeps this total for an out-of-range reference index.
        let referenceTZ = cities.indices.contains(referenceIndex)
            ? cities[referenceIndex].timeZone
            : .gmt
        let nowHourStart = floorToHour(now, in: referenceTZ)

        let columnInstants: [Date] = (0..<columnCount).map { i in
            nowHourStart.addingTimeInterval(Double(i - window.hoursBefore) * 3600)
        }

        let rows = cities.map { city in
            RowSnapshot(
                city: city,
                slots: slots(for: city, columnInstants: columnInstants, classifier: classifier)
            )
        }

        return RibbonSnapshot(
            now: now,
            columnInstants: columnInstants,
            nowColumnIndex: window.hoursBefore,
            rows: rows
        )
    }

    /// Bakes `count` consecutive hourly snapshots for a widget timeline: the first at the start
    /// of `now`'s hour (in the reference city's zone), each subsequent one advancing a fixed
    /// 3600 s. Each snapshot's `now` is its own (hour-aligned) instant, so the caller can use it
    /// directly as the timeline entry's date. Pure and WidgetKit-free — the Widget target wraps
    /// each snapshot in a `TimelineEntry`. Content only changes on the hour (the now-frame is
    /// fixed), so one call bakes a full day of entries and the reload budget is a non-issue.
    public static func hourlySnapshots(
        now: Date,
        cities: [City],
        count: Int = 24,
        window: WindowSpec = .init(),
        referenceIndex: Int = 0,
        classifier: SolarClassifier = .init()
    ) -> [RibbonSnapshot] {
        let referenceTZ = cities.indices.contains(referenceIndex)
            ? cities[referenceIndex].timeZone
            : .gmt
        let hourStart = floorToHour(now, in: referenceTZ)
        return (0..<max(0, count)).map { n in
            let date = hourStart.addingTimeInterval(Double(n) * 3600)
            return snapshot(
                now: date, cities: cities, window: window,
                referenceIndex: referenceIndex, classifier: classifier
            )
        }
    }

    // MARK: - Per-row slots

    private static func slots(
        for city: City,
        columnInstants: [Date],
        classifier: SolarClassifier
    ) -> [Slot] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone

        // Precompute each column's local day components so day-boundary detection compares
        // the same instants the hour/minute come from.
        let localComponents = columnInstants.map {
            calendar.dateComponents([.year, .month, .day, .hour, .minute], from: $0)
        }

        return columnInstants.indices.map { i in
            let c = localComponents[i]
            let isDayStart: Bool
            if i == 0 {
                isDayStart = (c.hour == 0)
            } else {
                let prev = localComponents[i - 1]
                isDayStart = (c.year != prev.year || c.month != prev.month || c.day != prev.day)
            }
            return Slot(
                columnIndex: i,
                instant: columnInstants[i],
                hour: c.hour ?? 0,
                minute: c.minute ?? 0,
                isDayStart: isDayStart,
                period: classifier.period(at: columnInstants[i], coordinate: city.coordinate)
            )
        }
    }

    // MARK: - Helpers

    /// Start of the hour containing `date` in `timeZone`, as an absolute instant.
    ///
    /// Uses the instant-based hour interval rather than reconstructing a date from
    /// year/month/day/hour components: during a DST fall-back the same wall-clock hour
    /// occurs twice, and `date(from:)` would resolve the ambiguous components to the
    /// *first* occurrence — anchoring the grid an hour off when `now` is in the second.
    private static func floorToHour(_ date: Date, in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.dateInterval(of: .hour, for: date)?.start ?? date
    }
}
