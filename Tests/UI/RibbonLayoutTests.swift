import XCTest
@testable import TimeStripUI

/// Invariants of the responsive `RibbonLayout` that keep the ribbon correct across
/// widget families (Medium — wide/short, Large — ~square) and row counts.
final class RibbonLayoutTests: XCTestCase {

    private let tiles: [CGSize] = [
        CGSize(width: 300, height: 120),   // ≈ .systemMedium content area
        CGSize(width: 300, height: 320),   // ≈ .systemLarge content area
    ]
    private let rowCounts = [2, 4, 6, 7]

    /// The rail plus the column grid exactly span the width — no leftover horizontal margin (this
    /// is what makes the content align to the tile edges like Apple's widgets).
    func testFillsWidthExactly() {
        for tile in tiles {
            let layout = RibbonLayout(size: tile, columns: 6, rows: 4)
            XCTAssertEqual(
                layout.railWidth + 6 * layout.slotWidth, tile.width, accuracy: 0.001,
                "rail + columns should span the full width at \(tile)"
            )
        }
    }

    /// Cells never go portrait — height is capped at the cell width — so the "vertically stretched"
    /// look can't happen regardless of family or row count.
    func testCellsNeverGoPortrait() {
        for tile in tiles {
            for rows in rowCounts {
                let layout = RibbonLayout(size: tile, columns: 6, rows: rows)
                XCTAssertLessThanOrEqual(
                    layout.rowHeight, layout.slotWidth + 0.001,
                    "cell went portrait at \(tile) with \(rows) rows"
                )
            }
        }
    }

    /// The stacked rows always fit within the container height (centered if shorter).
    func testContentFitsWithinHeight() {
        for tile in tiles {
            for rows in rowCounts {
                let layout = RibbonLayout(size: tile, columns: 6, rows: rows)
                XCTAssertLessThanOrEqual(
                    layout.contentHeight, tile.height + 0.001,
                    "content overflowed height at \(tile) with \(rows) rows"
                )
            }
        }
    }

    /// Every derived dimension stays finite and non-negative even for degenerate inputs (`.zero`,
    /// tiny/huge containers, 0/1 columns or rows), and the rail never exceeds the width — so the
    /// responsive math can't produce negative frames or non-positive font sizes.
    func testDegenerateInputsStayFiniteAndNonNegative() {
        let sizes: [CGSize] = [
            .zero,
            CGSize(width: 10, height: 10),
            CGSize(width: 40, height: 8),      // narrower than the rail's nominal minimum
            CGSize(width: 2000, height: 2000),
            CGSize(width: 329, height: 155),
        ]
        for size in sizes {
            for cols in [0, 1, 6] {
                for rows in [0, 1, 2, 7] {
                    let l = RibbonLayout(size: size, columns: cols, rows: rows)
                    let values = [
                        l.railWidth, l.ribbonWidth, l.slotWidth, l.railGap, l.rowHeight, l.rowSpacing,
                        l.contentHeight, l.rowCornerRadius, l.nowFrameBreathe, l.nowFrameCornerRadius,
                        l.hourFont, l.meridiemFont, l.cityFont, l.zoneFont,
                    ]
                    for v in values {
                        XCTAssertTrue(v.isFinite && v >= 0, "bad value \(v) at \(size) cols \(cols) rows \(rows)")
                    }
                    XCTAssertLessThanOrEqual(l.railWidth, max(size.width, 0) + 0.001)
                    XCTAssertGreaterThanOrEqual(l.ribbonWidth, -0.001)
                }
            }
        }
    }
}
