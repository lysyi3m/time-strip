import XCTest
@testable import TimeStripKit

final class RibbonFormatterTests: XCTestCase {

    // MARK: - Helpers

    private func slot(
        hour: Int, minute: Int = 0, isDayStart: Bool = false, instant: Date = Date()
    ) -> Slot {
        Slot(
            columnIndex: 0, instant: instant, hour: hour, minute: minute,
            isDayStart: isDayStart, period: .day
        )
    }

    private func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, tzid: String) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tzid)!
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        return cal.date(from: c)!
    }

    private func city(_ tzid: String) -> City {
        City(id: tzid, name: tzid, country: "", admin1: nil, tzid: tzid,
             coordinate: GeoCoordinate(latitude: 0, longitude: 0), population: 0)
    }

    private let en = Locale(identifier: "en_US")
    private let pl = Locale(identifier: "pl_PL")
    private let de = Locale(identifier: "de_DE")

    /// Independently derive the lowercased locale meridiem symbols.
    private func meridiem(_ locale: Locale) -> (am: String, pm: String) {
        let f = DateFormatter()
        f.locale = locale
        return ((f.amSymbol ?? "").lowercased(with: locale),
                (f.pmSymbol ?? "").lowercased(with: locale))
    }

    // MARK: - 1. Clock detection

    func testClockDetection() {
        XCTAssertTrue(RibbonFormatter.uses12HourClock(locale: en))
        XCTAssertFalse(RibbonFormatter.uses12HourClock(locale: pl))
        XCTAssertFalse(RibbonFormatter.uses12HourClock(locale: de))
    }

    // MARK: - 2. Hour labels

    func testHourLabels24h() {
        let l = RibbonFormatter.slotLabel(
            for: slot(hour: 7), timeZone: .gmt, locale: pl, is12h: false
        )
        XCTAssertEqual(l.primary, "07")
        XCTAssertEqual(l.secondary, "")
    }

    func testHourLabels24hSubHour() {
        let l = RibbonFormatter.slotLabel(
            for: slot(hour: 7, minute: 30), timeZone: .gmt, locale: pl, is12h: false
        )
        XCTAssertEqual(l.primary, "07:30")
        XCTAssertEqual(l.secondary, "")
    }

    func testHourLabels12h() {
        let (am, pm) = meridiem(en)

        let morning = RibbonFormatter.slotLabel(for: slot(hour: 7), timeZone: .gmt, locale: en, is12h: true)
        XCTAssertEqual(morning.primary, "7")
        XCTAssertEqual(morning.secondary, am)

        let evening = RibbonFormatter.slotLabel(for: slot(hour: 19), timeZone: .gmt, locale: en, is12h: true)
        XCTAssertEqual(evening.primary, "7")
        XCTAssertEqual(evening.secondary, pm)

        let noon = RibbonFormatter.slotLabel(for: slot(hour: 12), timeZone: .gmt, locale: en, is12h: true)
        XCTAssertEqual(noon.primary, "12")
        XCTAssertEqual(noon.secondary, pm)

        let midnight = RibbonFormatter.slotLabel(for: slot(hour: 0), timeZone: .gmt, locale: en, is12h: true)
        XCTAssertEqual(midnight.primary, "12")
        XCTAssertEqual(midnight.secondary, am)
    }

    func testHourLabels12hSubHour() {
        let l = RibbonFormatter.slotLabel(
            for: slot(hour: 7, minute: 30), timeZone: .gmt, locale: en, is12h: true
        )
        XCTAssertEqual(l.primary, "7:30")
        XCTAssertEqual(l.secondary, meridiem(en).am)
    }

    // MARK: - 3. Date slot

    func testDateSlot() {
        let tz = TimeZone(identifier: "Europe/Warsaw")!
        // 2026-07-16 is a Thursday.
        let instant = utc(2026, 7, 16, 9, 0, tzid: "Europe/Warsaw")
        let s = slot(hour: 0, isDayStart: true, instant: instant)

        // Expected values from an independent locale-aware formatter with the same tz.
        func expected(_ template: String, _ locale: Locale) -> String {
            let f = DateFormatter()
            f.locale = locale; f.timeZone = tz
            f.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: locale)
            return f.string(from: instant)
        }

        let enLabel = RibbonFormatter.slotLabel(for: s, timeZone: tz, locale: en, is12h: false)
        XCTAssertEqual(enLabel.primary, expected("d", en))
        XCTAssertEqual(enLabel.secondary, expected("EEE", en))
        XCTAssertEqual(enLabel.primary, "16")

        // Weekday localizes with the locale (e.g. Polish "czw").
        let plLabel = RibbonFormatter.slotLabel(for: s, timeZone: tz, locale: pl, is12h: false)
        XCTAssertEqual(plLabel.secondary, expected("EEE", pl))
    }

    // MARK: - 4. Zone tag

    func testZoneTagDSTOffset() {
        // macOS 15+/ICU returns GMT-offset abbreviations for European zones (no longer
        // "CEST"/"CET"), which the formatter normalizes to UTC±N. The offset still tracks
        // DST correctly (summer +2, winter +1).
        let warsaw = city("Europe/Warsaw")
        let summer = utc(2026, 7, 1, 12, 0, tzid: "UTC")
        let winter = utc(2026, 1, 1, 12, 0, tzid: "UTC")
        XCTAssertEqual(RibbonFormatter.zoneTag(for: warsaw, at: summer, override: nil), "UTC+2")
        XCTAssertEqual(RibbonFormatter.zoneTag(for: warsaw, at: winter, override: nil), "UTC+1")
    }

    func testZoneTagUTCOffsetFallback() {
        let instant = utc(2026, 7, 1, 12, 0, tzid: "UTC")
        XCTAssertEqual(
            RibbonFormatter.zoneTag(for: city("Asia/Singapore"), at: instant, override: nil),
            "UTC+8"
        )
        XCTAssertEqual(
            RibbonFormatter.zoneTag(for: city("Asia/Kolkata"), at: instant, override: nil),
            "UTC+5:30"
        )
    }

    func testZoneTagOverrideWins() {
        let warsaw = city("Europe/Warsaw")
        let summer = utc(2026, 7, 1, 12, 0, tzid: "UTC")
        XCTAssertEqual(
            RibbonFormatter.zoneTag(for: warsaw, at: summer, override: "Home"),
            "Home"
        )
    }

    func testZoneTagEmptyOverrideFallsThrough() {
        // Empty / whitespace-only override is treated as unset → computed tag, never blank.
        let singapore = city("Asia/Singapore")
        let instant = utc(2026, 7, 1, 12, 0, tzid: "UTC")
        XCTAssertEqual(RibbonFormatter.zoneTag(for: singapore, at: instant, override: ""), "UTC+8")
        XCTAssertEqual(RibbonFormatter.zoneTag(for: singapore, at: instant, override: "   "), "UTC+8")
    }
}
