import Foundation
import TimeStripKit

/// Fixed snapshots (2–5 rows, with/without a day boundary) shared by the app-target previews and
/// the UI tests. Built through the real `RibbonEngine` at a fixed instant, so shading and
/// boundaries are truthful. Not used by the shipping widget — that renders live provider data.
public enum RibbonFixtures {

    static let warsaw = City(name: "Warsaw", tzid: "Europe/Warsaw")
    static let london = City(name: "London", tzid: "Europe/London")
    static let newYork = City(name: "New York", tzid: "America/New_York")
    static let losAngeles = City(name: "Los Angeles", tzid: "America/Los_Angeles")
    static let singapore = City(name: "Singapore", tzid: "Asia/Singapore")

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
