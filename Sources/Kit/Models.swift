import Foundation

/// A place the user can put on a row: a city from the bundled table, or a bare OS time zone
/// labeled by its identifier's city. `tzid` is always an IANA identifier.
public struct City: Identifiable, Codable, Hashable, Sendable {
    public let name: String
    public let tzid: String        // IANA identifier, e.g. "Europe/Warsaw"
    public let admin: String       // first-level division, e.g. "Washington"; empty for a zone
    public let country: String     // ISO 3166 code, e.g. "US"; empty for a zone

    public var timeZone: TimeZone { TimeZone(identifier: tzid) ?? .gmt }
    public var isZone: Bool { country.isEmpty }

    public init(name: String, tzid: String, admin: String = "", country: String = "") {
        self.name = name
        self.tzid = tzid
        self.admin = admin
        self.country = country
    }

    /// Stable identity for pickers and saved widget configurations. A zone keeps its bare IANA
    /// id, so widgets saved before the city table still resolve. A city carries every field, so
    /// it resolves without the table even when a later table drops or renames it.
    public var id: String {
        isZone ? tzid : [tzid, name, admin, country].joined(separator: String(Self.separator))
    }

    /// Rebuilds a city from its `id`. A bare id is a zone, labeled from the identifier.
    public init?(id: String) {
        let parts = id.split(separator: Self.separator, omittingEmptySubsequences: false).map(String.init)
        switch parts.count {
        case 1:
            self.init(name: Self.zoneName(forTZID: id), tzid: id)
        case 4 where !parts[0].isEmpty && !parts[1].isEmpty && !parts[3].isEmpty:
            self.init(name: parts[1], tzid: parts[0], admin: parts[2], country: parts[3])
        default:
            return nil
        }
        guard TimeZone(identifier: tzid) != nil else { return nil }
    }

    /// Friendly name from an IANA id: last path segment, underscores → spaces.
    public static func zoneName(forTZID tzid: String) -> String {
        guard let last = tzid.split(separator: "/").last else { return tzid }
        return last.replacingOccurrences(of: "_", with: " ")
    }

    private static let separator: Character = "|"
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
        // Reject invalid windows at the boundary: negatives would later reach `0..<columnCount`
        // and trap, and enormous values would overflow `columnCount` or attempt a huge allocation.
        // A day either side is far more than any layout needs.
        precondition(
            (0...24).contains(hoursBefore) && (0...24).contains(hoursAfter),
            "WindowSpec hours must be within 0...24"
        )
        self.hoursBefore = hoursBefore
        self.hoursAfter = hoursAfter
    }

    public var columnCount: Int { hoursBefore + hoursAfter + 1 }   // default 6
}
