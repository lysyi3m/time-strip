import SwiftUI
import TimeStripKit
import WidgetKit

/// Dimensions the ribbon derives from the container it must fill. The layout is **responsive**
/// (fills the widget's content area edge-to-edge) rather than a fixed design scaled to fit — so it
/// matches Apple's content margins and adapts across families (`.systemMedium` fits fewer rows
/// than `.systemLarge`). Cells stay landscape: if the height would make a cell taller than ~its
/// width, the rows are centered with breathing room instead of being stretched into portrait.
struct RibbonLayout {
    let size: CGSize
    let columns: Int
    let rows: Int

    /// Inter-row gap as a fraction of the row height — a *ratio*, not fixed pixels, so gaps look
    /// consistent across families even though the cells themselves are sized differently.
    static let gapRatio: CGFloat = 0.22

    /// Rail is a fixed share of the width (hard-capped), NOT "whatever's left after the name" — so
    /// a long city name shrinks/truncates within the rail and never squeezes the cells. Also capped
    /// at half the width so `ribbonWidth` can never go negative on an unexpectedly small container.
    var railWidth: CGFloat { min((size.width * 0.24).clamped(60, 112), size.width * 0.5) }
    var ribbonWidth: CGFloat { size.width - railWidth }
    var slotWidth: CGFloat { ribbonWidth / CGFloat(max(columns, 1)) }

    /// A guaranteed gap between the rail text and the ribbon, so the city name never butts against
    /// its cells (the name shrinks/truncates to leave this gap regardless of font size).
    var railGap: CGFloat { (slotWidth * 0.26).clamped(8, 16) }

    /// Rows + proportional gaps fill the height, with the cell capped at square (never taller than
    /// its width → never portrait / stretched). When there are too few rows to fill, cells stay
    /// square and the block is centered with balanced breathing room.
    var rowHeight: CGFloat {
        let denom = CGFloat(rows) + CGFloat(max(rows - 1, 0)) * Self.gapRatio
        let fill = size.height / max(denom, 1)
        return min(slotWidth, fill)
    }
    var rowSpacing: CGFloat { rowHeight * Self.gapRatio }
    var contentHeight: CGFloat { CGFloat(rows) * rowHeight + CGFloat(max(rows - 1, 0)) * rowSpacing }

    var rowCornerRadius: CGFloat { rowHeight * 0.24 }
    var nowFrameBreathe: CGFloat { rowSpacing * 0.9 }
    var nowFrameCornerRadius: CGFloat { rowCornerRadius + nowFrameBreathe * 0.6 }

    var hourFont: CGFloat { rowHeight * 0.42 }
    var meridiemFont: CGFloat { rowHeight * 0.26 }
    var cityFont: CGFloat { min(rowHeight * 0.42, railWidth * 0.17) }
    var zoneFont: CGFloat { cityFont * 0.82 }
}

private extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { Swift.min(Swift.max(self, lo), hi) }
}

/// Renders a fully-resolved `RibbonSnapshot`, filling the container it's given. Each row is a wall-clock intensity gradient (night → day → dusk by local
/// hour), masked into one continuous bar whose only rounded corners are the row's outer ends; a
/// day boundary is marked by the date slot, not a gap. Static snapshot: no
/// hover/press/scrub/animation.
///
/// 12h vs 24h is derived from `locale` (not passed in) so it always reflects the render-time
/// locale / system clock preference rather than a value baked when the snapshot was made.
public struct RibbonView: View {
    private let snapshot: RibbonSnapshot
    private let locale: Locale
    @Environment(\.colorScheme) private var scheme

    public init(snapshot: RibbonSnapshot, locale: Locale = .current) {
        self.snapshot = snapshot
        self.locale = locale
    }

    private var is12h: Bool { RibbonFormatter.uses12HourClock(locale: locale) }
    private var columns: Int { snapshot.columnInstants.count }
    private var rowCount: Int { snapshot.rows.count }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // Guard degenerate geometry (a transient `.zero` from GeometryReader, a container too
            // small to render, or an empty snapshot) so the layout never produces negative sizes /
            // font points and the now-frame is never drawn over an empty grid.
            if size.width.isFinite, size.height.isFinite, size.width >= 1, size.height >= 1,
               columns > 0, rowCount > 0 {
                let layout = RibbonLayout(size: size, columns: columns, rows: rowCount)
                VStack(spacing: layout.rowSpacing) {
                    ForEach(snapshot.rows.indices, id: \.self) { i in
                        CityRow(
                            row: snapshot.rows[i],
                            now: snapshot.now,
                            is12h: is12h,
                            locale: locale,
                            nowColumnIndex: snapshot.nowColumnIndex,
                            layout: layout
                        )
                    }
                }
                // The now-frame is an overlay (it doesn't affect the row block's size), so the block
                // stays exactly `contentHeight` and centers cleanly. It spans every row as one
                // straight vertical line at the fixed nowColumnIndex, breathing above/below.
                .frame(width: size.width, height: layout.contentHeight)
                .overlay(alignment: .topLeading) { nowFrame(layout) }
                // Center the fixed-height block in the container (balanced breathing room).
                .frame(width: size.width, height: size.height)
            }
        }
    }

    /// A slab of polished crystal laid over the current column — not a stroked outline, and no
    /// milky frost. Reads from four light cues: a faint lift fill, a crisp 1px top specular, a soft
    /// inner shadow hugging the bottom inner edge, and a thin top-lit rim. Centered on the fixed
    /// nowColumnIndex; breathes above/below the row stack as one vertical line.
    private func nowFrame(_ layout: RibbonLayout) -> some View {
        let r = layout.nowFrameCornerRadius
        // Defensive: keep the marker on a valid column even if a malformed snapshot supplied an
        // out-of-range nowColumnIndex (the engine always produces a valid one).
        let nowColumn = min(max(snapshot.nowColumnIndex, 0), max(columns - 1, 0))
        let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
        return shape
            .fill(Palette.nowGlassFill(scheme))
            // Soft inner shadow hugging just the bottom inner edge (recessed crystal depth).
            .overlay(
                shape.fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.72),
                            .init(color: Palette.nowGlassInnerShadow(scheme), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            // Crisp 1px specular skimming the top edge — the polished highlight.
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Palette.nowGlassSpecular(scheme))
                    .frame(height: 1)
                    .padding(.horizontal, r * 0.5)
                    .padding(.top, 1)
                    .blur(radius: 0.3)
            }
            .overlay(shape.strokeBorder(Palette.nowGlassRim(scheme), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 7, x: 0, y: 2)
            .frame(
                width: layout.slotWidth,
                height: layout.contentHeight + 2 * layout.nowFrameBreathe
            )
            .offset(
                x: layout.railWidth + CGFloat(nowColumn) * layout.slotWidth,
                y: -layout.nowFrameBreathe
            )
            // In the accented mode the marker takes the accent tint, so *now* stands apart.
            .widgetAccentable()
            .allowsHitTesting(false)
    }
}

/// One city: left rail (name + zone tag) followed by its gradient-shaded `RibbonRow`.
private struct CityRow: View {
    let row: RowSnapshot
    let now: Date
    let is12h: Bool
    let locale: Locale
    let nowColumnIndex: Int
    let layout: RibbonLayout
    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var railLabel: Color { renderingMode == .fullColor ? Palette.railLabel(scheme) : .white }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: layout.rowHeight * 0.05) {
                Text(row.city.name)
                    .font(.system(size: layout.cityFont, weight: .semibold))
                    .tracking(-0.1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .truncationMode(.tail)
                    .foregroundStyle(railLabel)
                Text(RibbonFormatter.zoneTag(for: row.city, at: now))
                    .font(.system(size: layout.zoneFont, weight: .regular))
                    .tracking(0.1)
                    .foregroundStyle(railLabel.opacity(0.35))
            }
            .padding(.trailing, layout.railGap)   // guaranteed gap before the ribbon
            .frame(width: layout.railWidth, height: layout.rowHeight, alignment: .leading)
            // Whisper-faint left→right luminance lift (~3%) so the rail reads as its own material —
            // no divider, no border, just enough separation from the ribbon beside it.
            .background(
                LinearGradient(
                    colors: [.white.opacity(scheme == .dark ? 0.035 : 0.03), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            RibbonRow(row: row, is12h: is12h, locale: locale, nowColumnIndex: nowColumnIndex, layout: layout)
        }
        .frame(height: layout.rowHeight)
    }
}

/// Wall-clock band gradient background + fixed-position number-over-label content.
private struct RibbonRow: View {
    let row: RowSnapshot
    let is12h: Bool
    let locale: Locale
    let nowColumnIndex: Int
    let layout: RibbonLayout
    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var slots: [Slot] { row.slots }
    private var width: CGFloat { layout.ribbonWidth }
    /// Vibrant (the macOS desktop) and accented keep opacity but not color, so the ribbon swaps
    /// its color ramp for an opacity ramp there. See `Palette.tintedOpacity(forHour:_:)`.
    private var tinted: Bool { renderingMode != .fullColor }

    var body: some View {
        // The group confines the tinted modes' cut-out numbers (`.destinationOut`) to this row's
        // own cells. Full color needs no group, so it keeps its original render path.
        if tinted {
            band.compositingGroup()
        } else {
            band
        }
    }

    private var band: some View {
        ZStack(alignment: .leading) {
            // One continuous band gradient, masked so only the row's outer ends are rounded.
            // The mask partitions contiguous day runs without inserting any geometry or gap —
            // a day boundary is conveyed by the date slot, and column centers never move.
            Rectangle()
                .fill(bandGradient)
                .frame(width: width, height: layout.rowHeight)
                .overlay { if !tinted { materialShading } }
                .mask(runMask)
                // Ambient (not drop) shadow so each ribbon lifts just off the material.
                .shadow(color: .black.opacity(tinted ? 0 : 0.03), radius: 6, x: 0, y: 1)

            ForEach(slots.indices, id: \.self) { i in
                slotContent(i)
            }
        }
        .frame(width: width, height: layout.rowHeight)
    }

    private func cellColor(_ slot: Slot) -> Color {
        tinted
            ? .white.opacity(Palette.tintedOpacity(forHour: clockHour(slot), scheme))
            : Palette.color(forHour: clockHour(slot), scheme)
    }

    /// One shape per contiguous day-run; together they mask the row into a single continuous bar.
    /// Only the row's outer ends are rounded — the *first* run rounds its leading corners, the
    /// *last* run its trailing corners; every internal boundary corner is square. Pinned to the
    /// full ribbon width and leading-aligned so `.mask` (which centers by default) doesn't shift
    /// the runs off their columns.
    private var runMask: some View {
        let r = layout.rowCornerRadius
        return ZStack(alignment: .leading) {
            ForEach(dayRuns, id: \.start) { run in
                UnevenRoundedRectangle(
                    topLeadingRadius: run.roundLeading ? r : 0,
                    bottomLeadingRadius: run.roundLeading ? r : 0,
                    bottomTrailingRadius: run.roundTrailing ? r : 0,
                    topTrailingRadius: run.roundTrailing ? r : 0
                )
                .frame(width: run.width, height: layout.rowHeight)
                .offset(x: run.originX, y: 0)
            }
        }
        .frame(width: width, height: layout.rowHeight, alignment: .leading)
    }

    /// Contiguous spans of columns belonging to the same local day. A boundary falls *before* any
    /// column whose `isDayStart` is set (excluding index 0, the row's outer edge). Runs abut with
    /// no inserted geometry — each run spans exactly its slots, so column centers (the numbers)
    /// never move. `roundLeading`/`roundTrailing` mark the row's outer ends.
    private var dayRuns: [(start: Int, originX: CGFloat, width: CGFloat, roundLeading: Bool, roundTrailing: Bool)] {
        guard !slots.isEmpty else { return [] }  // `1...slots.count` would trap on an empty row
        let boundaries = Set(slots.indices.filter { $0 > 0 && slots[$0].isDayStart })
        var runs: [(start: Int, originX: CGFloat, width: CGFloat, roundLeading: Bool, roundTrailing: Bool)] = []
        var start = 0
        for end in 1...slots.count where end == slots.count || boundaries.contains(end) {
            runs.append((
                start: start,
                originX: CGFloat(start) * layout.slotWidth,
                width: CGFloat(end - start) * layout.slotWidth,
                roundLeading: start == 0,
                roundTrailing: end == slots.count
            ))
            start = end
        }
        return runs
    }

    /// Barely-there vertical material shading so each ribbon reads as a tangible object, not a flat
    /// swatch: a ~1px top highlight plus a gentle top-to-bottom darkening (≈100% → 94% luminance).
    /// Almost invisible in isolation; gives the surface subtle dimension. Applied before the
    /// run-mask so it clips to the row's shape.
    private var materialShading: some View {
        let edge = 1 / max(layout.rowHeight, 1)
        return LinearGradient(
            stops: [
                Gradient.Stop(color: .white.opacity(0.18), location: 0),
                Gradient.Stop(color: .white.opacity(0), location: edge),
                Gradient.Stop(color: .black.opacity(0), location: edge),
                Gradient.Stop(color: .black.opacity(0.06), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Local clock hour as a continuous value (sub-hour zones carry their :30/:45), so the color
    /// ramp differs slightly per column and the row reads as one smooth gradient.
    private func clockHour(_ slot: Slot) -> Double { Double(slot.hour) + Double(slot.minute) / 60 }

    /// A gradient with a stop at each column center colored by that column's position on the
    /// continuous time-of-day ramp (plus solid edges) — a smooth intensity gradient. The last ~5pt
    /// before each rounded end is held flat (a doubled edge stop) so the color doesn't keep ramping
    /// into the rounded corners, matching Apple's treatment of rounded surfaces.
    private var bandGradient: LinearGradient {
        guard let first = slots.first, let last = slots.last else {
            return LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
        }
        let n = slots.count
        let firstColor = cellColor(first)
        let lastColor = cellColor(last)
        let cap = min(5 / max(width, 1), CGFloat(0.5 / Double(n)))  // ~5pt, never past the first half-slot
        var stops: [Gradient.Stop] = [
            Gradient.Stop(color: firstColor, location: 0),
            Gradient.Stop(color: firstColor, location: cap),
        ]
        for i in slots.indices {
            let location = (Double(i) + 0.5) / Double(n)
            stops.append(Gradient.Stop(color: cellColor(slots[i]), location: location))
        }
        stops.append(Gradient.Stop(color: lastColor, location: 1 - cap))
        stops.append(Gradient.Stop(color: lastColor, location: 1))
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    @ViewBuilder
    private func slotContent(_ i: Int) -> some View {
        let slot = slots[i]
        let label = RibbonFormatter.slotLabel(
            for: slot, timeZone: row.city.timeZone, locale: locale, is12h: is12h
        )
        let numberColor = tinted ? .white : Palette.number(forHour: clockHour(slot), scheme)
        let cutout = tinted && Palette.tintedNumberIsCutout(forHour: clockHour(slot), scheme)
        let isNow = i == nowColumnIndex
        // Per-cell layout: a bare number centers vertically; a cell with a secondary (meridiem or
        // weekday) is a two-line group, centered. The now-column number is bolded so the current
        // hour reads regardless of the ribbon behind it — the glass marker alone can vanish over
        // bright daytime cells.
        // Slight negative spacing pulls the number and its meridiem/weekday a touch closer; the
        // 12h layout (every cell carries an am/pm) tightens by a further ~1pt.
        VStack(spacing: -layout.rowHeight * 0.05 - (is12h ? 1 : 0)) {
            Text(label.primary)
                .font(.system(size: layout.hourFont, weight: isNow ? .bold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.7)  // shrink to fit rather than truncate if cramped
            if !label.secondary.isEmpty {
                Text(label.secondary)
                    .font(.system(size: layout.meridiemFont, weight: .regular))
                    .tracking(0.1)
            }
        }
        .foregroundStyle(numberColor)
        .blendMode(cutout ? .destinationOut : .normal)
        .frame(width: layout.slotWidth, height: layout.rowHeight)
        .offset(x: CGFloat(i) * layout.slotWidth, y: 0)
    }
}
