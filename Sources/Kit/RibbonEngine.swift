import Foundation

/// Turns `(now, cities, window)` into a fully-resolved structural snapshot: a shared
/// absolute-time column grid, per-city rows, per-slot local time, and day-boundary flags.
///
/// The grid steps by a fixed 3600 s (not "add one clock hour"), so every column is one
/// absolute instant shared across all rows — the absolute-time-alignment invariant. Solar
/// `period` is a `.day` placeholder here; the real classification lands in Phase 2.
public enum RibbonEngine {
    public static func snapshot(
        now: Date,
        cities: [City],
        window: WindowSpec = .init(),
        referenceIndex: Int = 0
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
            RowSnapshot(city: city, slots: slots(for: city, columnInstants: columnInstants))
        }

        return RibbonSnapshot(
            now: now,
            columnInstants: columnInstants,
            nowColumnIndex: window.hoursBefore,
            rows: rows
        )
    }

    // MARK: - Per-row slots

    private static func slots(for city: City, columnInstants: [Date]) -> [Slot] {
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
                period: .day
            )
        }
    }

    // MARK: - Helpers

    /// Start of the hour containing `date` in `timeZone`, as an absolute instant.
    private static func floorToHour(_ date: Date, in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return calendar.date(from: comps) ?? date
    }
}
