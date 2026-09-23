import SwiftUI
import XCTest
@testable import TimeStripUI

/// The tinted rendering modes (vibrant, accented) carry the time-of-day shading as opacity. These
/// tests keep that opacity ramp inside its range and ordered like the full-color ramp.
final class PaletteTests: XCTestCase {

    private let schemes: [ColorScheme] = [.light, .dark]
    private let hours = stride(from: 0.0, to: 24.0, by: 0.25)

    func testTintedOpacityStaysInRange() {
        for scheme in schemes {
            for hour in hours {
                let opacity = Palette.tintedOpacity(forHour: hour, scheme)
                XCTAssertGreaterThanOrEqual(opacity, 0.05, "hour \(hour), \(scheme)")
                XCTAssertLessThanOrEqual(opacity, 0.85, "hour \(hour), \(scheme)")
            }
        }
    }

    /// Opacity must rise and fall with the full-color ramp's luminance, so both modes shade the
    /// same hours the same way.
    func testTintedOpacityFollowsLuminance() {
        for scheme in schemes {
            for a in hours {
                for b in hours {
                    let la = Palette.rgb(forHour: a, scheme).luminance
                    let lb = Palette.rgb(forHour: b, scheme).luminance
                    guard la < lb - 1e-9 else { continue }
                    XCTAssertLessThan(
                        Palette.tintedOpacity(forHour: a, scheme),
                        Palette.tintedOpacity(forHour: b, scheme),
                        "hours \(a) and \(b), \(scheme)"
                    )
                }
            }
        }
    }

    /// Midnight numbers draw solid on a faint cell; noon numbers are cut out of a strong one.
    func testNumbersCutOutOnlyOfStrongCells() {
        for scheme in schemes {
            XCTAssertFalse(Palette.tintedNumberIsCutout(forHour: 0, scheme), "\(scheme)")
            XCTAssertTrue(Palette.tintedNumberIsCutout(forHour: 12, scheme), "\(scheme)")
        }
    }
}
