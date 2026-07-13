import Foundation

public struct GeoCoordinate: Codable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct City: Identifiable, Codable, Hashable, Sendable {
    public let id: String          // stable slug, e.g. "europe-warsaw"
    public let name: String
    public let country: String
    public let admin1: String?
    public let tzid: String        // IANA identifier
    public let coordinate: GeoCoordinate
    public let population: Int

    public var timeZone: TimeZone { TimeZone(identifier: tzid) ?? .gmt }

    public init(
        id: String,
        name: String,
        country: String,
        admin1: String?,
        tzid: String,
        coordinate: GeoCoordinate,
        population: Int
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.admin1 = admin1
        self.tzid = tzid
        self.coordinate = coordinate
        self.population = population
    }
}

public enum DayPeriod: String, Codable, Hashable, Sendable {
    case day, twilight, night      // real values assigned in P2; P1 uses .day placeholder
}

public struct Slot: Hashable, Sendable {
    public let columnIndex: Int
    public let instant: Date        // the absolute column instant (shared across rows)
    public let hour: Int            // local hour 0...23 at `instant` in the city's tz
    public let minute: Int          // local minute (0 except sub-hour-offset zones)
    public let isDayStart: Bool     // first slot of a new local day → render date, not hour
    public var period: DayPeriod    // placeholder (.day) in P1

    public init(
        columnIndex: Int,
        instant: Date,
        hour: Int,
        minute: Int,
        isDayStart: Bool,
        period: DayPeriod
    ) {
        self.columnIndex = columnIndex
        self.instant = instant
        self.hour = hour
        self.minute = minute
        self.isDayStart = isDayStart
        self.period = period
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
