import XCTest
@testable import TimeStripKit

final class RibbonEngineTests: XCTestCase {

    // MARK: - Fixtures (inline City values; zones come from the OS list via CityCatalog)

    private var warsaw: City { City(name: "Warsaw", tzid: "Europe/Warsaw") }
    private var london: City { City(name: "London", tzid: "Europe/London") }
    private var newYork: City { City(name: "New York", tzid: "America/New_York") }
    private var singapore: City { City(name: "Singapore", tzid: "Asia/Singapore") }
    private var kolkata: City { City(name: "Kolkata", tzid: "Asia/Kolkata") }

    // MARK: - Helpers (independent of the engine)

    /// Build an absolute instant from wall-clock components in a specific time zone.
    private func instant(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int, _ minute: Int,
        tzid: String
    ) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tzid)!
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
        return cal.date(from: c)!
    }

    /// Independently compute the local hour of an instant in a time zone.
    private func localHour(_ date: Date, tzid: String) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tzid)!
        return cal.component(.hour, from: date)
    }

    /// Universal alignment invariant: every row's slot.hour matches the independently
    /// computed local hour of the shared column instant.
    private func assertRowsMatchLocalHours(
        _ snapshot: RibbonSnapshot,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        for row in snapshot.rows {
            for slot in row.slots {
                let expected = localHour(slot.instant, tzid: row.city.tzid)
                XCTAssertEqual(
                    slot.hour, expected,
                    "\(row.city.name) column \(slot.columnIndex)",
                    file: file, line: line
                )
            }
        }
    }

    /// Consecutive column instants are exactly 3600 s apart.
    private func assertUniformStride(
        _ instants: [Date],
        file: StaticString = #filePath, line: UInt = #line
    ) {
        for i in 1..<instants.count {
            XCTAssertEqual(
                instants[i].timeIntervalSince(instants[i - 1]), 3600,
                accuracy: 0.0001, "stride at \(i)", file: file, line: line
            )
        }
    }

    // MARK: - 1. Alignment & shape

    func testAlignmentAndShape() {
        let now = instant(2026, 7, 13, 12, 34, tzid: "UTC")
        let snapshot = RibbonEngine.snapshot(
            now: now, cities: [warsaw, london, newYork, singapore]
        )

        // Derived from the default window, not hardcoded, so it can't drift if the window changes.
        XCTAssertEqual(snapshot.columnInstants.count, WindowSpec().columnCount)
        XCTAssertEqual(snapshot.nowColumnIndex, WindowSpec().hoursBefore)
        assertUniformStride(snapshot.columnInstants)
        assertRowsMatchLocalHours(snapshot)

        // now sits in the nowColumnIndex slot (that hour's floor..<next hour).
        let nowInstant = snapshot.columnInstants[snapshot.nowColumnIndex]
        XCTAssertLessThanOrEqual(nowInstant, now)
        XCTAssertLessThan(now, nowInstant.addingTimeInterval(3600))
    }

    // MARK: - 2. DST transition (spring forward)

    func testSpringForwardSkipsHour() {
        // EU spring forward: 2026-03-29, Warsaw 02:00 CET → 03:00 CEST.
        let now = instant(2026, 3, 29, 4, 0, tzid: "Europe/Warsaw")
        let snapshot = RibbonEngine.snapshot(now: now, cities: [warsaw, singapore])

        assertUniformStride(snapshot.columnInstants)
        assertRowsMatchLocalHours(snapshot)

        let warsawHours = snapshot.rows[0].slots.map(\.hour)
        XCTAssertFalse(warsawHours.contains(2), "02 should be skipped: \(warsawHours)")
    }

    // MARK: - 3. DST transition (fall back)

    func testFallBackRepeatsHour() {
        // EU fall back: 2026-10-25, Warsaw 03:00 CEST → 02:00 CET (02:00 repeats).
        let now = instant(2026, 10, 25, 3, 0, tzid: "Europe/Warsaw")
        let snapshot = RibbonEngine.snapshot(now: now, cities: [warsaw, singapore])

        assertUniformStride(snapshot.columnInstants)
        assertRowsMatchLocalHours(snapshot)

        let twos = snapshot.rows[0].slots.filter { $0.hour == 2 }
        XCTAssertEqual(twos.count, 2, "02 should repeat once")
        // The two 02 slots are one absolute hour apart (the fall-back repeat).
        XCTAssertEqual(twos[1].instant.timeIntervalSince(twos[0].instant), 3600, accuracy: 0.0001)
    }

    /// Regression: with `now` in the *second* occurrence of the repeated fall-back hour,
    /// the grid must floor to that hour (not the first occurrence), so `now` sits inside
    /// its own column. Warsaw 2026-10-25: local 02:00 repeats — first at 00:00 UTC (CEST),
    /// second at 01:00 UTC (CET). now = 01:30 UTC is the second 02:30 local.
    func testFallBackSecondOccurrenceAnchorsGrid() {
        let now = instant(2026, 10, 25, 1, 30, tzid: "UTC")
        let snapshot = RibbonEngine.snapshot(now: now, cities: [warsaw, singapore])

        let nowInstant = snapshot.columnInstants[snapshot.nowColumnIndex]
        XCTAssertLessThanOrEqual(nowInstant, now)
        XCTAssertLessThan(now, nowInstant.addingTimeInterval(3600))
        // Concretely: the now column floors to 01:00 UTC (the second local 02:00).
        XCTAssertEqual(nowInstant, instant(2026, 10, 25, 1, 0, tzid: "UTC"))
        assertUniformStride(snapshot.columnInstants)
        assertRowsMatchLocalHours(snapshot)
    }

    // MARK: - 4. Sub-hour offset

    func testSubHourOffsetDoesNotPerturbGrid() {
        let now = instant(2026, 7, 13, 12, 34, tzid: "UTC")
        let base = RibbonEngine.snapshot(now: now, cities: [warsaw, london, newYork, singapore])
        let withKolkata = RibbonEngine.snapshot(
            now: now, cities: [warsaw, london, newYork, singapore, kolkata]
        )

        // Adding a sub-hour zone leaves the shared grid identical (same reference, index 0).
        XCTAssertEqual(withKolkata.columnInstants, base.columnInstants)
        assertRowsMatchLocalHours(withKolkata)

        let kolkataSlots = withKolkata.rows[4].slots
        XCTAssertTrue(kolkataSlots.allSatisfy { $0.minute == 30 }, "Kolkata is +5:30")

        // Hours increment by exactly one (mod 24) across the window — no DST in Kolkata.
        for i in 1..<kolkataSlots.count {
            XCTAssertEqual(kolkataSlots[i].hour, (kolkataSlots[i - 1].hour + 1) % 24)
        }
    }

    // MARK: - 5. Day boundary (midnight crossing)

    func testDayBoundaryFlag() {
        // Warsaw window sits mid-afternoon (no crossing); Singapore crosses local midnight.
        let now = instant(2026, 7, 13, 15, 30, tzid: "UTC")
        let snapshot = RibbonEngine.snapshot(now: now, cities: [warsaw, singapore])

        assertRowsMatchLocalHours(snapshot)

        // Reference row (Warsaw) has no crossing in this window.
        let warsawStarts = snapshot.rows[0].slots.filter(\.isDayStart)
        XCTAssertEqual(warsawStarts.count, 0)

        // Independently find where Singapore's local day changes across the shared grid.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Singapore")!
        let days = snapshot.columnInstants.map { cal.startOfDay(for: $0) }
        var expectedIndex: Int?
        for i in days.indices where i > 0 && days[i] != days[i - 1] {
            expectedIndex = i
        }
        // (index 0 counts only if local hour == 0, which is not the case here.)
        XCTAssertNotNil(expectedIndex, "test setup should cross Singapore midnight")

        let singaporeStarts = snapshot.rows[1].slots.filter(\.isDayStart)
        XCTAssertEqual(singaporeStarts.count, 1)
        XCTAssertEqual(singaporeStarts.first?.columnIndex, expectedIndex)

        let boundary = singaporeStarts.first!
        XCTAssertEqual(boundary.hour, 0, "new local day starts at hour 0")
        let comps = cal.dateComponents([.day], from: boundary.instant)
        let prevComps = cal.dateComponents([.day], from: snapshot.columnInstants[boundary.columnIndex - 1])
        XCTAssertNotEqual(comps.day, prevComps.day, "boundary slot is a new day-of-month")
    }

    // MARK: - 6. Reference index

    func testReferenceIndexFloorsToThatZone() {
        let now = instant(2026, 7, 13, 12, 34, tzid: "UTC")

        // Reference = Warsaw (whole offset): columns land on UTC-hour boundaries.
        let ref0 = RibbonEngine.snapshot(now: now, cities: [warsaw, kolkata], referenceIndex: 0)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertTrue(
            ref0.columnInstants.allSatisfy { utcCal.component(.minute, from: $0) == 0 },
            "whole-offset reference → columns on the UTC hour"
        )
        XCTAssertTrue(ref0.rows[0].slots.allSatisfy { $0.minute == 0 })

        // Reference = Kolkata (+5:30): flooring to Kolkata's hour shifts the grid by 30 min,
        // so whole-offset Warsaw rows now carry :30 minutes.
        let ref1 = RibbonEngine.snapshot(now: now, cities: [warsaw, kolkata], referenceIndex: 1)
        XCTAssertTrue(
            ref1.columnInstants.allSatisfy { utcCal.component(.minute, from: $0) == 30 },
            "Kolkata reference → columns fall on the UTC half-hour"
        )
        XCTAssertTrue(ref1.rows[0].slots.allSatisfy { $0.minute == 30 }, "Warsaw now carries :30")
        XCTAssertTrue(ref1.rows[1].slots.allSatisfy { $0.minute == 0 }, "Kolkata itself is whole")

        assertUniformStride(ref1.columnInstants)
        assertRowsMatchLocalHours(ref1)
    }
}
