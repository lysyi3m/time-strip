import SwiftUI
import TimeStripKit

/// Layout constants for `.systemExtraLarge`. `slotWidth` is the constant grid stride;
/// numbers sit at fixed per-index centers regardless of day boundaries (spec §6.2/§6.5).
private enum Metrics {
    // Slightly narrower cells free rail width for a larger city name, while staying comfortably
    // wider than tall. Content fills the `.systemExtraLarge` tile minus Apple's 16pt margin
    // (≈726×354 → ≈700×320): rail 156 + 8×68 = 700 wide; 5×56 + 4×10 = 320 tall.
    static let railWidth: CGFloat = 156
    static let slotWidth: CGFloat = 68
    static let rowHeight: CGFloat = 56
    static let rowSpacing: CGFloat = 10
    static let rowCornerRadius: CGFloat = 12
    /// No gap is carved at day boundaries (`boundaryGap = 0`) — the ribbon is one continuous
    /// bar (only the row's outer ends are rounded), so adjacent days meet seamlessly and the
    /// date slot marks the change. The now-frame is a rounded box around the current column that
    /// *breathes*: rather than hugging the ribbon, it stands off `nowFrameBreathe` pt above the
    /// first row and below the last (Apple lets key indicators breathe). Nothing is carved
    /// underneath, so its rounded corners sit cleanly over the solid ribbon.
    static let boundaryGap: CGFloat = 0
    /// The glass capsule overhangs the stack generously (not a hug) so it floats like a panel
    /// laid over the grid — matching the designer reference.
    static let nowFrameBreathe: CGFloat = 14
    static let nowFrameInsetX: CGFloat = 0
    static let nowFrameInsetY: CGFloat = -nowFrameBreathe
    static let nowFrameCornerRadius: CGFloat = 20
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
                        locale: locale,
                        nowColumnIndex: snapshot.nowColumnIndex
                    )
                }
            }
            nowFrame
        }
        .frame(width: Metrics.railWidth + ribbonWidth, height: rowsHeight, alignment: .topLeading)
    }

    /// A slab of frosted glass laid over the current column — not a stroked outline. Read from
    /// three light cues instead of a hard border (designer note): a faint translucent fill, a
    /// 1px inner shadow for recessed depth, and a top-lit 1px rim highlight. Centered on the
    /// fixed nowColumnIndex; breathes above/below the stack (invariant §6.3 — one vertical line).
    private var nowFrame: some View {
        let r = Metrics.nowFrameCornerRadius
        return RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(Palette.nowGlassFill(scheme)
                .shadow(.inner(color: Palette.nowGlassInnerShadow(scheme), radius: 1.5, x: 0, y: 1)))
            .overlay(
                // A crisp near-white rim tracing the whole capsule (brightest at the top). Unlike
                // a top-only highlight it reads on every side, so the marker stays legible over
                // bright daytime ribbons where a translucent fill alone would disappear.
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(Palette.nowGlassRim(scheme), lineWidth: 1.5)
            )
            // Soft ambient shadow so the panel floats above the grid and its edge separates from
            // the ribbons beneath (does most of its work in light mode).
            .shadow(color: .black.opacity(0.12), radius: 7, x: 0, y: 2)
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
    let nowColumnIndex: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.city.name)
                    .font(.system(size: 15, weight: .medium))
                    .tracking(-0.1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
                    .foregroundStyle(Palette.railLabel(scheme))
                Text(RibbonFormatter.zoneTag(for: row.city, at: now, override: nil))
                    .font(.system(size: 12, weight: .regular))
                    .tracking(0.2)
                    .foregroundStyle(Palette.railLabel(scheme).opacity(0.35))
            }
            .frame(width: Metrics.railWidth, alignment: .leading)
            // Whisper-faint fade so the rail feels seated in the material rather than printed on
            // top — brightest at the left edge, gone before it meets the ribbon.
            .background(
                LinearGradient(
                    colors: [Palette.railLabel(scheme).opacity(0.03), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            RibbonRow(row: row, is12h: is12h, locale: locale, nowColumnIndex: nowColumnIndex)
        }
    }
}

/// Wall-clock band gradient background + fixed-position number-over-label content.
private struct RibbonRow: View {
    let row: RowSnapshot
    let is12h: Bool
    let locale: Locale
    let nowColumnIndex: Int
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
                .overlay(materialShading)
                .mask(runMask)
                // Ambient (not drop) shadow — near-zero offset, soft, ~3% — so each ribbon lifts
                // just off the material rather than sitting flat on it.
                .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 1)

            ForEach(slots.indices, id: \.self) { i in
                slotContent(i)
            }
        }
        .frame(width: width, height: Metrics.rowHeight)
    }

    /// One shape per contiguous day-run; the union forms the row's shape with a carved gap at
    /// each day boundary. Only the row's outer ends are rounded — the *first* run rounds its
    /// leading corners, the *last* run its trailing corners; every internal boundary corner is
    /// square. Pinned to the full ribbon width and leading-aligned so `.mask` (which centers by
    /// default) doesn't shift the pills off their columns.
    private var runMask: some View {
        let r = Metrics.rowCornerRadius
        return ZStack(alignment: .leading) {
            ForEach(dayRuns, id: \.start) { run in
                UnevenRoundedRectangle(
                    topLeadingRadius: run.roundLeading ? r : 0,
                    bottomLeadingRadius: run.roundLeading ? r : 0,
                    bottomTrailingRadius: run.roundTrailing ? r : 0,
                    topTrailingRadius: run.roundTrailing ? r : 0
                )
                .frame(width: run.width, height: Metrics.rowHeight)
                .offset(x: run.originX, y: 0)
            }
        }
        .frame(width: width, height: Metrics.rowHeight, alignment: .leading)
    }

    /// Contiguous spans of columns belonging to the same local day. Boundaries fall *before*
    /// a column whose `isDayStart` is set (excluding index 0, the row's outer edge). Each run
    /// is inset by half the gap on any side that faces a boundary — the gap is carved from
    /// the slots, so column centers (the numbers) never move (invariant §6.2). `roundLeading`/
    /// `roundTrailing` mark the row's outer ends (the only rounded corners).
    private var dayRuns: [(start: Int, originX: CGFloat, width: CGFloat, roundLeading: Bool, roundTrailing: Bool)] {
        let boundaries = Set(slots.indices.filter { $0 > 0 && slots[$0].isDayStart })
        let half = Metrics.boundaryGap / 2
        var runs: [(start: Int, originX: CGFloat, width: CGFloat, roundLeading: Bool, roundTrailing: Bool)] = []
        var start = 0
        for end in 1...slots.count where end == slots.count || boundaries.contains(end) {
            let leadingGap = start > 0 ? half : 0        // boundary on the left edge
            let trailingGap = end < slots.count ? half : 0 // boundary on the right edge
            let originX = CGFloat(start) * Metrics.slotWidth + leadingGap
            let width = CGFloat(end - start) * Metrics.slotWidth - leadingGap - trailingGap
            runs.append((
                start: start, originX: originX, width: width,
                roundLeading: start == 0, roundTrailing: end == slots.count
            ))
            start = end
        }
        return runs
    }


    /// Barely-there vertical material shading so each ribbon reads as a tangible object, not a
    /// flat swatch (designer note): a hairline top highlight (0.5pt, fading out by ~4% down) plus
    /// a gentle top-to-bottom darkening (≈100% → 94% luminance). Almost invisible in isolation;
    /// gives the surface subtle dimension. Applied before the run-mask so it clips to the pills.
    private var materialShading: some View {
        let h = Metrics.rowHeight
        return LinearGradient(
            stops: [
                Gradient.Stop(color: .white.opacity(0.18), location: 0),
                Gradient.Stop(color: .white.opacity(0), location: 1 / h),   // crisp ~1px top edge
                Gradient.Stop(color: .black.opacity(0), location: 1 / h),
                Gradient.Stop(color: .black.opacity(0.06), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Local clock hour as a continuous value (sub-hour zones carry their :30/:45), so the
    /// color ramp differs slightly per column and the row reads as one smooth gradient.
    private func clockHour(_ slot: Slot) -> Double { Double(slot.hour) + Double(slot.minute) / 60 }

    /// A gradient with a stop at each column center colored by that column's position on the
    /// continuous time-of-day ramp (plus solid edges) — a smooth intensity gradient.
    private var bandGradient: LinearGradient {
        guard let first = slots.first, let last = slots.last else {
            return LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
        }
        let n = slots.count
        var stops: [Gradient.Stop] = [
            Gradient.Stop(color: Palette.color(forHour: clockHour(first), scheme), location: 0)
        ]
        for i in slots.indices {
            let location = (Double(i) + 0.5) / Double(n)
            stops.append(Gradient.Stop(color: Palette.color(forHour: clockHour(slots[i]), scheme), location: location))
        }
        stops.append(Gradient.Stop(color: Palette.color(forHour: clockHour(last), scheme), location: 1))
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    @ViewBuilder
    private func slotContent(_ i: Int) -> some View {
        let slot = slots[i]
        let label = RibbonFormatter.slotLabel(
            for: slot, timeZone: row.city.timeZone, locale: locale, is12h: is12h
        )
        let numberColor = Palette.number(forHour: clockHour(slot), scheme)
        let isNow = i == nowColumnIndex
        // Per-cell layout: a bare number centers vertically; a cell with a secondary
        // (meridiem or weekday) is a two-line group, centered. Tight spacing keeps the
        // label hugging the number (review: "tighter date layout"). The now-column number is
        // bolded so the current hour reads regardless of the ribbon behind it — the glass
        // marker alone can vanish over bright daytime cells.
        VStack(spacing: 0) {
            Text(label.primary)
                .font(.system(size: 16, weight: isNow ? .bold : .regular))
                .tracking(0)
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
