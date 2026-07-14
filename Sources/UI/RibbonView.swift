import SwiftUI
import TimeStripKit

/// Layout constants for `.systemExtraLarge`. `slotWidth` is the constant grid stride;
/// numbers sit at fixed per-index centers regardless of day boundaries (spec §6.2/§6.5).
private enum Metrics {
    // Sized so the natural content fills the `.systemExtraLarge` tile minus Apple's standard
    // 16pt widget content margin (spec §3 ≈ 726×354 → content ≈ 694×322): rail 94 + 8×75 =
    // 694 wide; 5×58 + 4×8 = 322 tall. Fonts (below) follow suit at ≥11pt with a clear
    // hierarchy per the HIG.
    static let railWidth: CGFloat = 94
    static let slotWidth: CGFloat = 75
    static let rowHeight: CGFloat = 58
    static let rowSpacing: CGFloat = 8
    static let rowCornerRadius: CGFloat = 12
    static let nowFrameLineWidth: CGFloat = 2
    /// Small gap carved at a day boundary; each day-run becomes its own rounded pill. The
    /// gap is *inset* from the two adjacent slots — column centers never move (invariant §6.2).
    static let boundaryGap: CGFloat = 6
    /// The now-frame sits a *uniform* `boundaryGap/2` outside the day-pills on every side: its
    /// right edge bisects the carved gap (`insetX = 0` → on the slot boundary, gap/2 beyond the
    /// pill edge), and it overhangs the row stack by the same gap/2 vertically. With a corner
    /// radius of `rowCornerRadius + gap/2`, the frame's rounded corners share a center with the
    /// day-pill corners where they meet a boundary — concentric curves, constant gap.
    static let nowFrameInsetX: CGFloat = 0
    static let nowFrameInsetY: CGFloat = -boundaryGap / 2
    static let nowFrameCornerRadius: CGFloat = rowCornerRadius + boundaryGap / 2
}

/// Renders a fully-resolved `RibbonSnapshot` per the structural rules in spec §4/§6.
/// Each row is a wall-clock band gradient (night/dawn/day/dusk by local hour, blended
/// across columns); a day boundary carves a small gap between two rounded day-run pills
/// (inset from the slots, so column centers hold). Static snapshot: no
/// hover/press/scrub/animation.
public struct RibbonView: View {
    private let snapshot: RibbonSnapshot
    private let is12h: Bool
    private let locale: Locale
    @Environment(\.colorScheme) private var scheme

    public init(snapshot: RibbonSnapshot, is12h: Bool, locale: Locale = .current) {
        self.snapshot = snapshot
        self.is12h = is12h
        self.locale = locale
    }

    /// The ribbon's natural (unscaled) size for a snapshot, from the fixed layout metrics.
    /// Callers that must fit it into a container (e.g. a widget of unknown bounds) use this to
    /// compute a scale factor — Apple's guidance is to adapt to the container, since widget
    /// sizes vary by device/platform and are only known at runtime (`displaySize`).
    public static func idealSize(for snapshot: RibbonSnapshot) -> CGSize {
        let cols = snapshot.columnInstants.count
        let rows = snapshot.rows.count
        return CGSize(
            width: Metrics.railWidth + CGFloat(cols) * Metrics.slotWidth,
            height: CGFloat(rows) * Metrics.rowHeight
                + CGFloat(max(0, rows - 1)) * Metrics.rowSpacing
        )
    }

    private var columnCount: Int { snapshot.columnInstants.count }
    private var ribbonWidth: CGFloat { CGFloat(columnCount) * Metrics.slotWidth }
    private var rowsHeight: CGFloat {
        CGFloat(snapshot.rows.count) * Metrics.rowHeight
            + CGFloat(max(0, snapshot.rows.count - 1)) * Metrics.rowSpacing
    }

    public var body: some View {
        // The now-frame is drawn last, on top, spanning every row as one straight vertical
        // line at the fixed nowColumnIndex (invariant §6.3).
        ZStack(alignment: .topLeading) {
            VStack(spacing: Metrics.rowSpacing) {
                ForEach(snapshot.rows.indices, id: \.self) { i in
                    RowView(
                        row: snapshot.rows[i],
                        now: snapshot.now,
                        is12h: is12h,
                        locale: locale
                    )
                }
            }
            nowFrame
        }
        .frame(width: Metrics.railWidth + ribbonWidth, height: rowsHeight, alignment: .topLeading)
    }

    private var nowFrame: some View {
        // Overhangs the stack top/bottom, centered on the fixed nowColumnIndex. Uses `.stroke`
        // (centered on the edge), not `.strokeBorder` (inset inward) — so the border straddles
        // the slot boundary and bisects an adjacent day-gap symmetrically, rather than sitting
        // a half-stroke inside it (which made the 23→border and border→date gaps unequal).
        RoundedRectangle(cornerRadius: Metrics.nowFrameCornerRadius)
            .stroke(Palette.nowFrame(scheme), lineWidth: Metrics.nowFrameLineWidth)
            .frame(
                width: Metrics.slotWidth - 2 * Metrics.nowFrameInsetX,
                height: rowsHeight - 2 * Metrics.nowFrameInsetY
            )
            .offset(
                x: Metrics.railWidth
                    + CGFloat(snapshot.nowColumnIndex) * Metrics.slotWidth
                    + Metrics.nowFrameInsetX,
                y: Metrics.nowFrameInsetY
            )
            .allowsHitTesting(false)
    }
}

/// One city: left rail (name + zone tag) followed by its gradient-shaded ribbon.
private struct RowView: View {
    let row: RowSnapshot
    let now: Date
    let is12h: Bool
    let locale: Locale
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.city.name)
                    .font(.system(size: 13, weight: .medium))
                    .tracking(-0.1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
                    .foregroundStyle(Palette.railLabel(scheme))
                Text(RibbonFormatter.zoneTag(for: row.city, at: now, override: nil))
                    .font(.system(size: 11, weight: .regular))
                    .tracking(0.2)
                    .foregroundStyle(Palette.railLabel(scheme).opacity(0.5))
            }
            .frame(width: Metrics.railWidth, alignment: .leading)

            RibbonRow(row: row, is12h: is12h, locale: locale)
        }
    }
}

/// Wall-clock band gradient background + fixed-position number-over-label content.
private struct RibbonRow: View {
    let row: RowSnapshot
    let is12h: Bool
    let locale: Locale
    @Environment(\.colorScheme) private var scheme

    private var slots: [Slot] { row.slots }
    private var width: CGFloat { CGFloat(slots.count) * Metrics.slotWidth }

    var body: some View {
        ZStack(alignment: .leading) {
            // One continuous band gradient, masked into per-day rounded pills so a day
            // boundary reads as a small gap between two rounded runs (not a hairline).
            Rectangle()
                .fill(bandGradient)
                .frame(width: width, height: Metrics.rowHeight)
                .mask(runMask)

            ForEach(slots.indices, id: \.self) { i in
                slotContent(i)
            }
        }
        .frame(width: width, height: Metrics.rowHeight)
    }

    /// A rounded rectangle per contiguous day-run; the union forms the row's shape with a
    /// carved gap at each day boundary. Pinned to the full ribbon width and leading-aligned
    /// so `.mask` (which centers by default) doesn't shift the pills off their columns.
    private var runMask: some View {
        ZStack(alignment: .leading) {
            ForEach(dayRuns, id: \.start) { run in
                RoundedRectangle(cornerRadius: Metrics.rowCornerRadius)
                    .frame(width: run.width, height: Metrics.rowHeight)
                    .offset(x: run.originX, y: 0)
            }
        }
        .frame(width: width, height: Metrics.rowHeight, alignment: .leading)
    }

    /// Contiguous spans of columns belonging to the same local day. Boundaries fall *before*
    /// a column whose `isDayStart` is set (excluding index 0, the row's outer edge). Each run
    /// is inset by half the gap on any side that faces a boundary — the gap is carved from
    /// the slots, so column centers (the numbers) never move (invariant §6.2).
    private var dayRuns: [(start: Int, originX: CGFloat, width: CGFloat)] {
        let boundaries = Set(slots.indices.filter { $0 > 0 && slots[$0].isDayStart })
        let half = Metrics.boundaryGap / 2
        var runs: [(start: Int, originX: CGFloat, width: CGFloat)] = []
        var start = 0
        for end in 1...slots.count where end == slots.count || boundaries.contains(end) {
            let leadingGap = start > 0 ? half : 0        // boundary on the left edge
            let trailingGap = end < slots.count ? half : 0 // boundary on the right edge
            let originX = CGFloat(start) * Metrics.slotWidth + leadingGap
            let width = CGFloat(end - start) * Metrics.slotWidth - leadingGap - trailingGap
            runs.append((start: start, originX: originX, width: width))
            start = end
        }
        return runs
    }


    /// A gradient with a stop at each column center colored by that column's wall-clock band
    /// (plus solid edges), so same-band runs read flat and adjacent bands blend across one
    /// slot — a "live" ribbon with no solar math.
    private var bandGradient: LinearGradient {
        guard let firstHour = slots.first?.hour, let lastHour = slots.last?.hour else {
            return LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
        }
        let n = slots.count
        var stops: [Gradient.Stop] = [
            Gradient.Stop(color: Palette.color(forHour: firstHour, scheme), location: 0)
        ]
        for i in slots.indices {
            let location = (Double(i) + 0.5) / Double(n)
            stops.append(Gradient.Stop(color: Palette.color(forHour: slots[i].hour, scheme), location: location))
        }
        stops.append(Gradient.Stop(color: Palette.color(forHour: lastHour, scheme), location: 1))
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    @ViewBuilder
    private func slotContent(_ i: Int) -> some View {
        let slot = slots[i]
        let label = RibbonFormatter.slotLabel(
            for: slot, timeZone: row.city.timeZone, locale: locale, is12h: is12h
        )
        let numberColor = Palette.number(forHour: slot.hour, scheme)
        // Per-cell layout: a bare number centers vertically; a cell with a secondary
        // (meridiem or weekday) is a two-line group, centered.
        VStack(spacing: 1) {
            Text(label.primary)
                .font(.system(size: 16, weight: .medium))
                .tracking(-0.2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)  // shrink to fit rather than truncate if cramped
            if !label.secondary.isEmpty {
                Text(label.secondary)
                    .font(.system(size: 11, weight: .regular))
                    .tracking(0.2)
            }
        }
        .foregroundStyle(numberColor)
        .frame(width: Metrics.slotWidth, height: Metrics.rowHeight)
        .offset(x: CGFloat(i) * Metrics.slotWidth, y: 0)
    }
}
