import Foundation

/// A time zone the user can place on a row, labeled by a representative city. Sourced from the
/// OS zone list (`CityCatalog`), so `tzid` is an IANA identifier and `name` its friendly city
/// name. `label` is an optional per-row manual override for the zone tag (§3), set by the
/// widget configuration; the catalog leaves it `nil`.
public struct City: Identifiable, Codable, Hashable, Sendable {
    public let name: String
    public let tzid: String        // IANA identifier, e.g. "Europe/Warsaw"
    public let label: String?      // manual zone-tag override, or nil to auto-derive

    /// Stable identity for pickers/entities — the IANA id is already unique and stable.
    public var id: String { tzid }
    public var timeZone: TimeZone { TimeZone(identifier: tzid) ?? .gmt }

    public init(name: String, tzid: String, label: String? = nil) {
        self.name = name
        self.tzid = tzid
        self.label = label
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
}

public struct WindowSpec: Sendable, Equatable {
    public let hoursBefore: Int         // default 2
    public let hoursAfter: Int          // default 5

    public init(hoursBefore: Int = 2, hoursAfter: Int = 5) {
        self.hoursBefore = hoursBefore
        self.hoursAfter = hoursAfter
    }

    public var columnCount: Int { hoursBefore + hoursAfter + 1 }   // default 8
}
