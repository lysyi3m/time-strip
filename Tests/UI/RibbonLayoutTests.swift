import XCTest
@testable import TimeStripUI

/// P8/redesign: invariants of the responsive `RibbonLayout` that keep the ribbon correct across
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
}
