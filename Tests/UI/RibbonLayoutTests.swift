import XCTest
import TimeStripKit
import TimeStripUI

/// P8: layout guarantees of the ribbon view that the Kit-only tests can't reach.
final class RibbonLayoutTests: XCTestCase {

    private let pool = [
        "Europe/Warsaw", "America/New_York", "Asia/Singapore", "Europe/London", "America/Los_Angeles",
    ]

    private func snapshot(rows: Int) -> RibbonSnapshot {
        let cities = (0..<rows).map { City(name: "C\($0)", tzid: pool[$0 % pool.count]) }
        return RibbonEngine.snapshot(now: Date(timeIntervalSince1970: 1_784_000_000), cities: cities)
    }

    /// Width comes from the fixed 8-column grid (rail + columns), so it must not vary with the
    /// number of rows.
    func testIdealWidthIsIndependentOfRowCount() {
        let widths = (2...5).map { RibbonView.idealSize(for: snapshot(rows: $0)).width }
        XCTAssertEqual(Set(widths).count, 1, "width must depend only on the column grid: \(widths)")
        XCTAssertGreaterThan(widths[0], 0)
    }

    /// Each added row adds one row height plus one inter-row gap — a constant — so ideal height is
    /// affine in the row count. Verified from the data itself (no hardcoded metrics that can drift).
    func testIdealHeightGrowsLinearlyWithRows() {
        let heights = (1...5).map { RibbonView.idealSize(for: snapshot(rows: $0)).height }
        let deltas = zip(heights.dropFirst(), heights).map { $0 - $1 }
        XCTAssertTrue(
            deltas.allSatisfy { abs($0 - deltas[0]) < 0.0001 },
            "height should increase by a constant per row: \(heights)"
        )
        XCTAssertGreaterThan(heights[0], 0)
    }
}
