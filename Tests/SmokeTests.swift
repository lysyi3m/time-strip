import XCTest
@testable import TimeStripKit

final class SmokeTests: XCTestCase {
    func testSchemaVersion() {
        XCTAssertEqual(TimeStrip.schemaVersion, 1)
    }
}
