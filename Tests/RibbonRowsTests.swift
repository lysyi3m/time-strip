import XCTest
@testable import TimeStripKit

/// The pure configuration-resolution decision behind the widget provider.
final class RibbonRowsTests: XCTestCase {

    private let la = City(name: "Los Angeles", tzid: "America/Los_Angeles")
    private let ny = City(name: "New York", tzid: "America/New_York")
    private let defaults = [
        City(name: "London", tzid: "Europe/London"),
        City(name: "Warsaw", tzid: "Europe/Warsaw"),
    ]

    func testEmptyFallsBackToDefaults() {
        XCTAssertEqual(RibbonRows.resolve(configured: [], defaults: defaults), .ribbon(defaults))
    }

    func testSingleCityPrompts() {
        XCTAssertEqual(RibbonRows.resolve(configured: [la], defaults: defaults), .setupNeeded)
    }

    func testTwoDistinctCitiesRender() {
        XCTAssertEqual(RibbonRows.resolve(configured: [la, ny], defaults: defaults), .ribbon([la, ny]))
    }

    func testDuplicateCityCollapsesToOneAndPrompts() {
        // The same city chosen twice is one distinct city → too few to compare.
        let dup = City(name: "Los Angeles", tzid: "America/Los_Angeles")
        XCTAssertEqual(RibbonRows.resolve(configured: [la, dup], defaults: defaults), .setupNeeded)
    }

    func testCitiesSharingAZoneStayDistinctRows() {
        let seattle = City(name: "Seattle", tzid: "America/Los_Angeles", admin: "Washington", country: "US")
        XCTAssertEqual(RibbonRows.resolve(configured: [la, seattle], defaults: defaults), .ribbon([la, seattle]))
    }

    func testZoneAndCityOfTheSameNameCollapse() {
        // A widget saved before the city table holds the bare zone; the table city reads the same.
        let tableLA = City(name: "Los Angeles", tzid: "America/Los_Angeles", admin: "California", country: "US")
        XCTAssertEqual(RibbonRows.resolve(configured: [la, tableLA, ny], defaults: defaults), .ribbon([la, ny]))
    }

    func testDeduplicationPreservesOrderAndDropsLaterDuplicates() {
        let result = RibbonRows.resolve(configured: [la, ny, la], defaults: defaults)
        XCTAssertEqual(result, .ribbon([la, ny]))
    }

    func testDeduplicationKeepsFirstOccurrenceOrder() {
        let dupLA = City(name: "Los Angeles", tzid: "America/Los_Angeles")
        guard case let .ribbon(rows) = RibbonRows.resolve(configured: [la, ny, dupLA], defaults: defaults) else {
            return XCTFail("expected a ribbon")
        }
        XCTAssertEqual(rows.map(\.tzid), ["America/Los_Angeles", "America/New_York"])
    }
}
