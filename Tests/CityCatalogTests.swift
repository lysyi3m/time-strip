import XCTest
@testable import TimeStripKit

/// The OS-sourced zone catalog behind the widget's city picker.
final class CityCatalogTests: XCTestCase {

    func testAllZonesAreOSSourcedAndRegionQualified() {
        let all = CityCatalog.all
        let known = Set(TimeZone.knownTimeZoneIdentifiers)
        XCTAssertFalse(all.isEmpty)
        for city in all {
            XCTAssertTrue(known.contains(city.tzid), "\(city.tzid) should be an OS identifier")
            XCTAssertTrue(city.tzid.contains("/"), "bare/region-less ids are dropped: \(city.tzid)")
            XCTAssertNotNil(TimeZone(identifier: city.tzid), "must resolve: \(city.tzid)")
        }
        // Sorted by display name.
        let names = all.map(\.name)
        XCTAssertEqual(names, names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }

    func testDisplayNameDerivation() {
        XCTAssertEqual(CityCatalog.displayName(forTZID: "America/New_York"), "New York")
        XCTAssertEqual(CityCatalog.displayName(forTZID: "Europe/Warsaw"), "Warsaw")
        XCTAssertEqual(CityCatalog.displayName(forTZID: "America/Argentina/Buenos_Aires"), "Buenos Aires")
        XCTAssertEqual(CityCatalog.region(forTZID: "Asia/Tokyo"), "Asia")
    }

    func testLookupByID() {
        let city = CityCatalog.city(forID: "Europe/Warsaw")
        XCTAssertEqual(city?.name, "Warsaw")
        XCTAssertEqual(city?.id, "Europe/Warsaw")
        XCTAssertNil(CityCatalog.city(forID: "Not/AZone"))
    }

    func testSearchIsCaseAndDiacriticInsensitiveAndPrefixRanked() {
        let results = CityCatalog.search("warsaw")
        XCTAssertEqual(results.first?.tzid, "Europe/Warsaw")

        // Diacritic-insensitive: "Sao Paulo" matches "São Paulo".
        XCTAssertTrue(
            CityCatalog.search("sao paulo").contains { $0.tzid == "America/Sao_Paulo" },
            "diacritic-insensitive search should find São Paulo"
        )

        // Prefix beats substring: querying "york" surfaces New York.
        XCTAssertTrue(CityCatalog.search("york").contains { $0.tzid == "America/New_York" })

        // Empty query yields the curated suggestions.
        XCTAssertEqual(CityCatalog.search("   ").map(\.tzid), CityCatalog.suggested.map(\.tzid))
    }

    func testSearchLimitIsClampedNotTrapping() {
        // A negative limit must not trap `.prefix`; it clamps to an empty result.
        XCTAssertTrue(CityCatalog.search("warsaw", limit: -5).isEmpty)
        XCTAssertEqual(CityCatalog.search("warsaw", limit: 1).count, 1)
    }

    func testSuggestedAndDefaultsResolve() {
        XCTAssertFalse(CityCatalog.suggested.isEmpty)
        XCTAssertEqual(CityCatalog.defaults.map(\.tzid), [
            "America/Los_Angeles", "America/New_York", "Europe/London", "Europe/Warsaw",
            "Asia/Dubai", "Asia/Singapore", "Asia/Tokyo",
        ])
    }
}
