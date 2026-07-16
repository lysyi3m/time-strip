import Foundation

/// A time zone the user can place on a row, labeled by a representative city. Sourced from the
/// OS zone list (`CityCatalog`), so `tzid` is an IANA identifier and `name` its friendly city
/// name.
public struct City: Identifiable, Codable, Hashable, Sendable {
    public let name: String
    public let tzid: String        // IANA identifier, e.g. "Europe/Warsaw"

    /// Stable identity for pickers/entities — the IANA id is already unique and stable.
    public var id: String { tzid }
    public var timeZone: TimeZone { TimeZone(identifier: tzid) ?? .gmt }

    public init(name: String, tzid: String) {
        self.name = name
        self.tzid = tzid
    }
}

public struct Slot: Hashable, Sendable {
    public let columnIndex: Int
    public let instant: Date        // the absolute column instant (shared across rows)
    public let hour: Int            // local hour 0...23 at `instant` in the city's tz
    public let minute: Int          // local minute (0 except sub-hour-offset zones)
    public let isDayStart: Bool     // first slot of a new local day → render date, not hour

    public init(
        columnIndex: Int,
        instant: Date,
        hour: Int,
        minute: Int,
        isDayStart: Bool
    ) {
        self.columnIndex = columnIndex
        self.instant = instant
        self.hour = hour
        self.minute = minute
        self.isDayStart = isDayStart
    }
}

public struct RowSnapshot: Hashable, Sendable {
    public let city: City
    public let slots: [Slot]        // one per column, count == window.columnCount

    public init(city: City, slots: [Slot]) {
        self.city = city
        self.slots = slots
    }
}

public struct RibbonSnapshot: Hashable, Sendable {
    public let now: Date
    public let columnInstants: [Date]   // absolute instants, one per column
    public let nowColumnIndex: Int      // == window.hoursBefore
    public let rows: [RowSnapshot]

    public init(
        now: Date,
        columnInstants: [Date],
        nowColumnIndex: Int,
        rows: [RowSnapshot]
    ) {
        self.now = now
        self.columnInstants = columnInstants
        self.nowColumnIndex = nowColumnIndex
        self.rows = rows
    }

    /// The same snapshot showing at most `maxRows` rows (the shared column grid is unchanged) —
    /// used to fit one baked snapshot into a family that renders fewer rows than were configured.
    public func trimmedToRows(_ maxRows: Int) -> RibbonSnapshot {
        guard maxRows < rows.count else { return self }
        return RibbonSnapshot(
            now: now,
            columnInstants: columnInstants,
            nowColumnIndex: nowColumnIndex,
            rows: Array(rows.prefix(max(0, maxRows)))
        )
    }
}

public struct WindowSpec: Sendable, Equatable {
    public let hoursBefore: Int         // default 2 → `now` sits at column index 2
    public let hoursAfter: Int          // default 3

    // Default −2h/+3h = 6 columns: `now` stays at column index 2, and the trimmed future window
    // keeps the strip readable in the compact `.systemMedium` tile (an 8-column window packs the
    // cells too tightly there). `now`'s fixed position is preserved.
    public init(hoursBefore: Int = 2, hoursAfter: Int = 3) {
        // A window can't extend a negative number of hours; a negative count would later reach
        // `0..<columnCount` and trap deep in the engine. Reject at the boundary instead.
        precondition(hoursBefore >= 0 && hoursAfter >= 0, "WindowSpec hours must be non-negative")
        self.hoursBefore = hoursBefore
        self.hoursAfter = hoursAfter
    }

    public var columnCount: Int { hoursBefore + hoursAfter + 1 }   // default 6
}
