import XCTest
@testable import TimeStripKit

/// The bundled city table and OS zones behind the widget's city picker.
final class CityCatalogTests: XCTestCase {

    func testEveryCityHasAZoneTheOSResolves() {
        let cities = CityCatalog.cities
        XCTAssertGreaterThan(cities.count, 10_000)
        for city in cities {
            XCTAssertNotNil(TimeZone(identifier: city.tzid), "\(city.name) has an unknown zone \(city.tzid)")
            XCTAssertFalse(city.name.isEmpty)
            XCTAssertEqual(city.country.count, 2, "\(city.name) needs an ISO country code")
        }
    }

    func testCitiesWithoutTheirOwnZoneAreFound() throws {
        // Neither city names an IANA zone: Seattle shares Los Angeles's, Astana shares Almaty's.
        let seattle = try XCTUnwrap(CityCatalog.search("Seattle").first)
        XCTAssertEqual(seattle.name, "Seattle")
        XCTAssertEqual(seattle.country, "US")
        XCTAssertEqual(seattle.timeZone.identifier, TimeZone(identifier: "America/Los_Angeles")?.identifier)

        let astana = try XCTUnwrap(CityCatalog.search("astana").first)
        XCTAssertEqual(astana.name, "Astana")
        XCTAssertEqual(astana.country, "KZ")
    }

    func testOSZonesStayPickableWithoutDuplicatingCities() {
        let zones = CityCatalog.zones
        let known = Set(TimeZone.knownTimeZoneIdentifiers)
        XCTAssertFalse(zones.isEmpty)
        for zone in zones {
            XCTAssertTrue(zone.isZone)
            XCTAssertTrue(known.contains(zone.tzid), "\(zone.tzid) should be an OS identifier")
            XCTAssertTrue(zone.tzid.contains("/"), "bare/region-less ids are dropped: \(zone.tzid)")
        }
        // The Los Angeles city covers the America/Los_Angeles zone, so the zone row is dropped.
        XCTAssertFalse(zones.contains { $0.tzid == "America/Los_Angeles" })
        XCTAssertEqual(CityCatalog.search("los angeles").filter { $0.name == "Los Angeles" }.count, 1)
        // A zone no city names stays: the table calls the city Kolkata.
        XCTAssertTrue(zones.contains { $0.tzid == "Asia/Calcutta" })
    }

    func testZoneNameDerivation() {
        XCTAssertEqual(City.zoneName(forTZID: "America/New_York"), "New York")
        XCTAssertEqual(City.zoneName(forTZID: "America/Argentina/Buenos_Aires"), "Buenos Aires")
    }

    func testIDRoundTripsAndResolvesWithoutTheTable() {
        let city = City(name: "Seattle", tzid: "America/Los_Angeles", admin: "Washington", country: "US")
        XCTAssertEqual(CityCatalog.city(forID: city.id), city)

        // A widget saved before the city table holds a bare IANA id.
        let zone = CityCatalog.city(forID: "Europe/Warsaw")
        XCTAssertEqual(zone, City(name: "Warsaw", tzid: "Europe/Warsaw"))
        XCTAssertEqual(zone?.id, "Europe/Warsaw")
        XCTAssertEqual(zone?.isZone, true)

        XCTAssertNil(CityCatalog.city(forID: "Not/AZone"))
        XCTAssertNil(CityCatalog.city(forID: "Not/AZone|Nowhere||US"))
        XCTAssertNil(CityCatalog.city(forID: "Europe/Warsaw|Warsaw"))
    }

    func testSubtitleTellsSameNamedCitiesApart() {
        let en = Locale(identifier: "en_US")
        let portland = City(name: "Portland", tzid: "America/Los_Angeles", admin: "Oregon", country: "US")
        XCTAssertEqual(CityCatalog.subtitle(for: portland, locale: en), "Oregon, United States")
        let singapore = City(name: "Singapore", tzid: "Asia/Singapore", admin: "", country: "SG")
        XCTAssertEqual(CityCatalog.subtitle(for: singapore, locale: en), "Singapore")
        XCTAssertEqual(CityCatalog.subtitle(for: City(name: "Calcutta", tzid: "Asia/Calcutta"), locale: en), "Asia/Calcutta")
    }

    func testSearchIsCaseAndDiacriticInsensitive() {
        XCTAssertEqual(CityCatalog.search("WARSAW").first?.name, "Warsaw")
        XCTAssertTrue(CityCatalog.search("sao paulo").contains { $0.name == "São Paulo" })
        // Folding does not turn Ł into L; the table's ASCII name covers it.
        XCTAssertTrue(CityCatalog.search("lodz").contains { $0.name == "Łódź" })
    }

    func testSearchRanksByMatchThenPopulation() {
        // The largest Paris beats Paris, Texas.
        XCTAssertEqual(CityCatalog.search("paris").first?.country, "FR")
        // A word prefix inside the name still finds the city.
        XCTAssertTrue(CityCatalog.search("york").contains { $0.name == "New York City" })
        // A country name finds its cities.
        XCTAssertTrue(CityCatalog.search("Kazakhstan").contains { $0.name == "Astana" })
        // Empty query yields the curated suggestions.
        XCTAssertEqual(CityCatalog.search("   "), CityCatalog.suggested)
    }

    func testSearchLimitIsClampedNotTrapping() {
        // A negative limit must not trap `.prefix`; it clamps to an empty result.
        XCTAssertTrue(CityCatalog.search("warsaw", limit: -5).isEmpty)
        XCTAssertEqual(CityCatalog.search("warsaw", limit: 1).count, 1)
    }

    func testSuggestedAndDefaultsResolve() {
        XCTAssertEqual(CityCatalog.suggested.count, 25, "every popular city must be in the table")
        XCTAssertEqual(CityCatalog.defaults.map(\.tzid), [
            "America/Los_Angeles", "America/New_York", "Europe/London", "Europe/Warsaw",
            "Asia/Dubai", "Asia/Singapore", "Asia/Tokyo",
        ])
    }
}
