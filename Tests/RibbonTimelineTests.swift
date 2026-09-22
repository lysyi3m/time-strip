import XCTest
@testable import TimeStripKit

/// The pure timeline-baking helper the Widget wraps in `TimelineEntry`s.
final class RibbonTimelineTests: XCTestCase {

    private var warsaw: City { City(name: "Warsaw", tzid: "Europe/Warsaw") }
    private var singapore: City { City(name: "Singapore", tzid: "Asia/Singapore") }

    private func instant(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, tzid: String) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tzid)!
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        return cal.date(from: c)!
    }

    // MARK: - Count & default

    func testBakesRequestedCount() {
        let now = instant(2026, 7, 13, 12, 34, tzid: "UTC")
        XCTAssertEqual(RibbonEngine.hourlySnapshots(now: now, cities: [warsaw, singapore]).count, 24)
        XCTAssertEqual(
            RibbonEngine.hourlySnapshots(now: now, cities: [warsaw, singapore], count: 6).count, 6
        )
    }

    // MARK: - Hour-aligned dates advancing by 3600 s

    func testEntriesAreHourAlignedAndAdvanceHourly() {
        // 12:34 UTC → first entry floors to 12:00 UTC (Warsaw whole-offset reference).
        let now = instant(2026, 7, 13, 12, 34, tzid: "UTC")
        let snaps = RibbonEngine.hourlySnapshots(now: now, cities: [warsaw, singapore])

        let firstHour = instant(2026, 7, 13, 12, 0, tzid: "UTC")
        XCTAssertEqual(snaps.first?.now, firstHour)

        for (n, snap) in snaps.enumerated() {
            // Each snapshot's `now` is exactly the aligned entry instant, and usable as the
            // entry date directly.
            XCTAssertEqual(snap.now, firstHour.addingTimeInterval(Double(n) * 3600))
        }
        for i in 1..<snaps.count {
            XCTAssertEqual(snaps[i].now.timeIntervalSince(snaps[i - 1].now), 3600, accuracy: 0.0001)
        }
    }

    // MARK: - Content advances hour to hour

    func testConsecutiveSnapshotsAdvanceOneHour() {
        let now = instant(2026, 7, 13, 12, 34, tzid: "UTC")
        let snaps = RibbonEngine.hourlySnapshots(now: now, cities: [warsaw, singapore], count: 3)

        // The now-column's local hour for the reference row advances by one each entry.
        let refHours = snaps.map { $0.rows[0].slots[$0.nowColumnIndex].hour }
        for i in 1..<refHours.count {
            XCTAssertEqual(refHours[i], (refHours[i - 1] + 1) % 24, "ref now-hour advances by 1")
        }

        // And each entry's own snapshot honors the alignment invariant.
        for snap in snaps {
            for row in snap.rows {
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = row.city.timeZone
                for slot in row.slots {
                    XCTAssertEqual(slot.hour, cal.component(.hour, from: slot.instant))
                }
            }
        }
    }

    // MARK: - Degenerate input

    func testZeroCountIsEmpty() {
        let now = instant(2026, 7, 13, 12, 34, tzid: "UTC")
        XCTAssertTrue(RibbonEngine.hourlySnapshots(now: now, cities: [warsaw], count: 0).isEmpty)
    }
}
