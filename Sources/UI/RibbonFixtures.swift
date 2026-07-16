import Foundation
import TimeStripKit

/// Fixed snapshots (2–6 rows, with/without a day boundary) shared by the app-target previews and
/// the UI tests. Built through the real `RibbonEngine` at a fixed instant, so shading and
/// boundaries are truthful. Not used by the shipping widget — that renders live provider data.
public enum RibbonFixtures {

    static let warsaw = City(name: "Warsaw", tzid: "Europe/Warsaw")
    static let london = City(name: "London", tzid: "Europe/London")
    static let newYork = City(name: "New York", tzid: "America/New_York")
    static let losAngeles = City(name: "Los Angeles", tzid: "America/Los_Angeles")
    static let singapore = City(name: "Singapore", tzid: "Asia/Singapore")
    static let dubai = City(name: "Dubai", tzid: "Asia/Dubai")
    static let tokyo = City(name: "Tokyo", tzid: "Asia/Tokyo")

    /// A `now` whose window crosses Singapore's local midnight → one row shows a boundary.
    static let boundaryNow = Date(timeIntervalSince1970: 1_784_129_400)  // 2026-07-13 15:30 UTC

    static func snapshot(_ cities: [City], now: Date = boundaryNow) -> RibbonSnapshot {
        RibbonEngine.snapshot(now: now, cities: cities)
    }

    public static var twoRows: RibbonSnapshot { snapshot([warsaw, singapore]) }
    public static var threeRows: RibbonSnapshot { snapshot([warsaw, newYork, singapore]) }
    /// The first four of the widget's default city set — the `.systemMedium` view.
    public static var fourRows: RibbonSnapshot { snapshot([losAngeles, newYork, london, singapore]) }
    /// West → east by longitude; mirrors the widget's default city set (`CityCatalog.defaults`) —
    /// the `.systemLarge` view.
    public static var sevenRows: RibbonSnapshot {
        snapshot([losAngeles, newYork, london, warsaw, dubai, singapore, tokyo])
    }

    /// A window with no in-window day boundary for any row.
    public static var noBoundary: RibbonSnapshot {
        snapshot([warsaw, london, newYork], now: Date(timeIntervalSince1970: 1_784_106_000))  // 09:00 UTC
    }
}
