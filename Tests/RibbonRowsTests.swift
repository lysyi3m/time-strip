import XCTest
@testable import TimeStripKit

/// P6/P8: the pure configuration-resolution decision behind the widget provider.
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

    func testDuplicateZoneCollapsesToOneAndPrompts() {
        // The same zone chosen twice is one distinct zone → too few to compare.
        let dup = City(name: "Los Angeles", tzid: "America/Los_Angeles")
        XCTAssertEqual(RibbonRows.resolve(configured: [la, dup], defaults: defaults), .setupNeeded)
    }

    func testDeduplicationPreservesOrderAndDropsLaterDuplicates() {
        let result = RibbonRows.resolve(configured: [la, ny, la], defaults: defaults)
        XCTAssertEqual(result, .ribbon([la, ny]))
    }

    func testFirstSlotLabelWinsForARepeatedZone() {
        let first = City(name: "Los Angeles", tzid: "America/Los_Angeles", label: "Home")
        let second = City(name: "Los Angeles", tzid: "America/Los_Angeles", label: "Office")
        guard case let .ribbon(rows) = RibbonRows.resolve(configured: [first, second, ny], defaults: defaults) else {
            return XCTFail("expected a ribbon")
        }
        XCTAssertEqual(rows.map(\.tzid), ["America/Los_Angeles", "America/New_York"])
        XCTAssertEqual(rows.first?.label, "Home", "first occurrence's label should win")
    }
}
