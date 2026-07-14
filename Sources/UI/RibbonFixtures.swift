import Foundation
import TimeStripKit

/// Hardcoded snapshots for Phase 4 previews and the P0/P4 widget placeholder. Built through
/// the real `RibbonEngine` so shading and boundaries are truthful. Replaced by the timeline
/// provider's live data in P5.
public enum RibbonFixtures {

    static func city(_ id: String, _ name: String, _ tzid: String, _ lat: Double, _ lon: Double) -> City {
        City(
            id: id, name: name, country: "", admin1: nil, tzid: tzid,
            coordinate: GeoCoordinate(latitude: lat, longitude: lon), population: 0
        )
    }

    static let warsaw = city("europe-warsaw", "Warsaw", "Europe/Warsaw", 52.2297, 21.0122)
    static let london = city("europe-london", "London", "Europe/London", 51.5074, -0.1278)
    static let newYork = city("america-new-york", "New York", "America/New_York", 40.7128, -74.0060)
    static let losAngeles = city("america-los-angeles", "Los Angeles", "America/Los_Angeles", 34.0522, -118.2437)
    static let singapore = city("asia-singapore", "Singapore", "Asia/Singapore", 1.3521, 103.8198)

    /// A `now` whose window crosses Singapore's local midnight → one row shows a boundary.
    static let boundaryNow = Date(timeIntervalSince1970: 1_784_129_400)  // 2026-07-13 15:30 UTC

    static func snapshot(_ cities: [City], now: Date = boundaryNow) -> RibbonSnapshot {
        RibbonEngine.snapshot(now: now, cities: cities)
    }

    public static var twoRows: RibbonSnapshot { snapshot([warsaw, singapore]) }
    public static var threeRows: RibbonSnapshot { snapshot([warsaw, newYork, singapore]) }
    public static var fourRows: RibbonSnapshot { snapshot([london, warsaw, newYork, singapore]) }
    /// West → east by longitude; also the intended initial default city order.
    public static var fiveRows: RibbonSnapshot { snapshot([losAngeles, newYork, london, warsaw, singapore]) }

    /// A window with no in-window day boundary for any row.
    public static var noBoundary: RibbonSnapshot {
        snapshot([warsaw, london, newYork], now: Date(timeIntervalSince1970: 1_784_106_000))  // 09:00 UTC
    }
}
