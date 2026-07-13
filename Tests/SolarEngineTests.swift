import XCTest
@testable import TimeStripKit

final class SolarEngineTests: XCTestCase {

    private let classifier = SolarClassifier()

    private func coordinate(_ lat: Double, _ lon: Double) -> GeoCoordinate {
        GeoCoordinate(latitude: lat, longitude: lon)
    }

    /// Build an absolute UTC instant from wall-clock components.
    private func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        return cal.date(from: c)!
    }

    // Mid-latitude reference point.
    private let warsaw = GeoCoordinate(latitude: 52.2297, longitude: 21.0122)

    // MARK: - 1. Noon vs midnight

    func testNoonIsDayMidnightIsNight() {
        // Warsaw local solar noon ≈ 12:00 − lon/15 h in UTC ≈ 10:36 UTC (winter).
        let noon = utc(2026, 1, 15, 10, 36)
        let midnight = utc(2026, 1, 15, 22, 36)

        XCTAssertEqual(classifier.period(at: noon, coordinate: warsaw), .day)
        XCTAssertEqual(classifier.period(at: midnight, coordinate: warsaw), .night)
        XCTAssertGreaterThan(classifier.elevation(at: noon, coordinate: warsaw), 0)
        XCTAssertLessThan(classifier.elevation(at: midnight, coordinate: warsaw),
                          SolarClassifier.civilTwilightThreshold)
    }

    // MARK: - 2. Twilight window (day → twilight → night, in order)

    func testTwilightBracketsThresholds() {
        // Scan a Warsaw summer evening minute-by-minute through sunset.
        var previous: DayPeriod = .day
        var sawDay = false, sawTwilight = false, sawNight = false
        var dayToTwilightElevation: Double?
        var twilightToNightElevation: Double?

        for minute in 0...(6 * 60) {          // 18:00 → 00:00 UTC
            let t = utc(2026, 6, 21, 18, 0).addingTimeInterval(Double(minute) * 60)
            let el = classifier.elevation(at: t, coordinate: warsaw)
            let p = classifier.period(at: t, coordinate: warsaw)

            switch p {
            case .day: sawDay = true
            case .twilight: sawTwilight = true
            case .night: sawNight = true
            }

            // Transitions must proceed day → twilight → night, never reverse.
            if p != previous {
                switch (previous, p) {
                case (.day, .twilight): dayToTwilightElevation = el
                case (.twilight, .night): twilightToNightElevation = el
                default:
                    XCTFail("unexpected transition \(previous) → \(p) at minute \(minute)")
                }
                previous = p
            }
        }

        XCTAssertTrue(sawDay && sawTwilight && sawNight, "evening should span all three periods")
        // The band edges sit essentially on the thresholds (within algorithm + 1-min step).
        XCTAssertEqual(dayToTwilightElevation ?? .nan, SolarClassifier.dayThreshold, accuracy: 0.3)
        XCTAssertEqual(twilightToNightElevation ?? .nan, SolarClassifier.civilTwilightThreshold, accuracy: 0.3)
    }

    // MARK: - 3. Reference cross-check against a published sunrise

    func testSunriseMatchesPublishedValue() {
        // New York, 2026-06-21: published sunrise ≈ 05:25 EDT = 09:25 UTC.
        let nyc = coordinate(40.7128, -74.0060)
        let expected = utc(2026, 6, 21, 9, 25)

        // Find the upward crossing of the day threshold (−0.833°) by minute scan.
        var crossing: Date?
        var previousElevation = classifier.elevation(
            at: utc(2026, 6, 21, 8, 0), coordinate: nyc
        )
        for minute in 1...(3 * 60) {           // 08:00 → 11:00 UTC
            let t = utc(2026, 6, 21, 8, 0).addingTimeInterval(Double(minute) * 60)
            let el = classifier.elevation(at: t, coordinate: nyc)
            if previousElevation < SolarClassifier.dayThreshold, el >= SolarClassifier.dayThreshold {
                crossing = t
                break
            }
            previousElevation = el
        }

        XCTAssertNotNil(crossing)
        XCTAssertEqual(
            crossing!.timeIntervalSince(expected), 0, accuracy: 8 * 60,
            "computed sunrise within 8 min of published 09:25 UTC"
        )
    }

    // MARK: - 4. Polar safety (no crash, no NaN)

    func testPolarSolsticesAreStable() {
        let longyearbyen = coordinate(78.2232, 15.6267)

        // Sample a full day at both solstices.
        func periods(onYear year: Int, month: Int, day: Int) -> [DayPeriod] {
            (0..<24).map { hour in
                let t = utc(year, month, day, hour, 0)
                let el = classifier.elevation(at: t, coordinate: longyearbyen)
                XCTAssertFalse(el.isNaN, "elevation must never be NaN")
                return classifier.period(at: t, coordinate: longyearbyen)
            }
        }

        // Midnight sun: every sample is day.
        XCTAssertTrue(periods(onYear: 2026, month: 6, day: 21).allSatisfy { $0 == .day })
        // Polar night: no sample is day.
        XCTAssertFalse(periods(onYear: 2026, month: 12, day: 21).contains(.day))
    }

    // MARK: - 5. Elevation peaks near local solar noon

    func testElevationPeaksAtSolarNoon() {
        // Solar noon (UTC) ≈ 12:00 − lon/15 h; EoT shifts it a few minutes.
        let expectedNoon = utc(2026, 6, 21, 12, 0)
            .addingTimeInterval(-warsaw.longitude / 15.0 * 3600.0)

        var best = Date.distantPast
        var bestElevation = -Double.infinity
        for minute in 0..<(24 * 60) {
            let t = utc(2026, 6, 21, 0, 0).addingTimeInterval(Double(minute) * 60)
            let el = classifier.elevation(at: t, coordinate: warsaw)
            if el > bestElevation { bestElevation = el; best = t }
        }

        XCTAssertEqual(best.timeIntervalSince(expectedNoon), 0, accuracy: 20 * 60,
                       "peak elevation within 20 min of computed solar noon")
        XCTAssertGreaterThan(bestElevation, 0)
    }

    // MARK: - Engine wiring

    func testEngineFillsRealPeriods() {
        // A daytime instant over a spread of longitudes yields a mix of periods, not all .day.
        let cities = [
            City(id: "asia-singapore", name: "Singapore", country: "", admin1: nil,
                 tzid: "Asia/Singapore",
                 coordinate: coordinate(1.3521, 103.8198), population: 0),
            City(id: "america-los-angeles", name: "Los Angeles", country: "", admin1: nil,
                 tzid: "America/Los_Angeles",
                 coordinate: coordinate(34.0522, -118.2437), population: 0),
        ]
        let snapshot = RibbonEngine.snapshot(now: utc(2026, 6, 21, 6, 0), cities: cities)
        let allPeriods = snapshot.rows.flatMap { $0.slots.map(\.period) }
        XCTAssertGreaterThan(Set(allPeriods).count, 1, "engine should populate varied periods")
    }
}
