import SwiftUI
import TimeStripKit

/// Layout constants for `.systemExtraLarge`. `slotWidth` is the constant grid stride;
/// numbers sit at fixed per-index centers regardless of day boundaries (spec §6.2/§6.5).
private enum Metrics {
    static let railWidth: CGFloat = 96
    static let slotWidth: CGFloat = 78
    static let rowHeight: CGFloat = 54
    static let rowSpacing: CGFloat = 8
    static let rowCornerRadius: CGFloat = 12
    static let nowFrameCornerRadius: CGFloat = 14
    static let nowFrameLineWidth: CGFloat = 2
    /// Number of elevation samples across a row for the solar gradient.
    static let gradientSamples = 48
}

/// Renders a fully-resolved `RibbonSnapshot` per the structural rules in spec §4/§6.
/// Each row is a continuous solar gradient (day/twilight/night shaded by the sun's
/// elevation across the window); the day boundary is signaled by the date slot alone —
/// no carved notch. Static snapshot: no hover/press/scrub/animation.
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
                        columnInstants: snapshot.columnInstants,
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
        RoundedRectangle(cornerRadius: Metrics.nowFrameCornerRadius)
            .strokeBorder(Palette.nowFrame(scheme), lineWidth: Metrics.nowFrameLineWidth)
            .frame(width: Metrics.slotWidth, height: rowsHeight)
            .offset(x: Metrics.railWidth + CGFloat(snapshot.nowColumnIndex) * Metrics.slotWidth, y: 0)
            .allowsHitTesting(false)
    }
}

/// One city: left rail (name + zone tag) followed by its gradient-shaded ribbon.
private struct RowView: View {
    let row: RowSnapshot
    let columnInstants: [Date]
    let now: Date
    let is12h: Bool
    let locale: Locale
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.city.name)
                    .font(.system(size: 11, weight: .regular))
                    .tracking(-0.1)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(Palette.railLabel(scheme))
                Text(RibbonFormatter.zoneTag(for: row.city, at: now, override: nil))
                    .font(.system(size: 9, weight: .regular))
                    .tracking(0.2)
                    .foregroundStyle(Palette.railLabel(scheme).opacity(0.5))
            }
            .frame(width: Metrics.railWidth, alignment: .leading)

            RibbonRow(row: row, columnInstants: columnInstants, is12h: is12h, locale: locale)
        }
    }
}

/// Continuous solar gradient background + fixed-position number-over-label content.
private struct RibbonRow: View {
    let row: RowSnapshot
    let columnInstants: [Date]
    let is12h: Bool
    let locale: Locale
    @Environment(\.colorScheme) private var scheme

    private static let classifier = SolarClassifier()
    private var slots: [Slot] { row.slots }
    private var width: CGFloat { CGFloat(slots.count) * Metrics.slotWidth }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: Metrics.rowCornerRadius)
                .fill(solarGradient)

            // Subtle day-boundary tick (no notch): a faint vertical hairline at midnight.
            ForEach(boundaryIndices, id: \.self) { i in
                Rectangle()
                    .fill(Palette.boundaryTick(scheme))
                    .frame(width: 1, height: Metrics.rowHeight - 12)
                    .offset(x: CGFloat(i) * Metrics.slotWidth - 0.5, y: 0)
            }

            ForEach(slots.indices, id: \.self) { i in
                slotContent(i)
            }
        }
        .frame(width: width, height: Metrics.rowHeight)
    }

    /// Columns that begin a new local day, excluding index 0 (its boundary would sit on the
    /// row's outer edge).
    private var boundaryIndices: [Int] {
        slots.indices.filter { $0 > 0 && slots[$0].isDayStart }
    }


    private func elevation(at instant: Date) -> Double {
        Self.classifier.elevation(at: instant, coordinate: row.city.coordinate)
    }

    /// Whether the sun is ascending at `instant` (dawn side) vs descending (dusk side).
    private func isRising(at instant: Date) -> Bool {
        elevation(at: instant.addingTimeInterval(600)) > elevation(at: instant)
    }

    /// Sample the sun's elevation across the full bar (half a column before the first
    /// center to half a column after the last), producing smooth dawn/dusk transitions
    /// that land at the true solar times, not on column boundaries.
    private var solarGradient: LinearGradient {
        let stride: TimeInterval = 3600
        guard let first = columnInstants.first, let last = columnInstants.last else {
            return LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
        }
        let t0 = first.addingTimeInterval(-stride / 2)
        let t1 = last.addingTimeInterval(stride / 2)
        let span = t1.timeIntervalSince(t0)

        let stops: [Gradient.Stop] = (0..<Metrics.gradientSamples).map { s in
            let f = Double(s) / Double(Metrics.gradientSamples - 1)
            let instant = t0.addingTimeInterval(span * f)
            let color = Palette.color(
                forElevation: elevation(at: instant), rising: isRising(at: instant), scheme
            )
            return Gradient.Stop(color: color, location: f)
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    @ViewBuilder
    private func slotContent(_ i: Int) -> some View {
        let slot = slots[i]
        let label = RibbonFormatter.slotLabel(
            for: slot, timeZone: row.city.timeZone, locale: locale, is12h: is12h
        )
        let numberColor = Palette.number(
            onElevation: elevation(at: slot.instant), rising: isRising(at: slot.instant), scheme
        )
        // Per-cell layout: a bare number centers vertically; a cell with a secondary
        // (meridiem or weekday) is a two-line group, centered.
        VStack(spacing: 1) {
            Text(label.primary)
                .font(.system(size: 16, weight: .medium))
                .tracking(-0.2)
            if !label.secondary.isEmpty {
                Text(label.secondary)
                    .font(.system(size: 9, weight: .regular))
                    .tracking(0.2)
            }
        }
        .foregroundStyle(numberColor)
        .frame(width: Metrics.slotWidth, height: Metrics.rowHeight)
        .offset(x: CGFloat(i) * Metrics.slotWidth, y: 0)
    }
}
