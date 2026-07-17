import SwiftUI
import TimeStripKit
import TimeStripUI

/// The host app's single screen. Time Strip has no in-app settings — everything is configured on
/// the widget itself — so this window only explains how to add and edit the widget, and shows a
/// live preview of what it looks like. There's no deep-link into the widget editor (no public
/// API exists), so the guidance is instructional only.
///
/// Presentation: a soft gradient canvas, the real widget floating on a "desktop" panel with a
/// drop shadow (so it reads as a placed widget, not a flat swatch), and the steps grouped in an
/// elevated card — rather than bare content on a plain window.
struct OnboardingView: View {
    @Environment(\.colorScheme) private var scheme

    private let snapshot = RibbonEngine.snapshot(now: Date(), cities: CityCatalog.defaults)
    private var dark: Bool { scheme == .dark }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            hero
            stepsCard
        }
        .padding(30)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .background(canvas)
    }

    private var canvas: some View {
        LinearGradient(
            colors: dark ? [Color(hex: 0x232329), Color(hex: 0x161618)]
                         : [Color(hex: 0xFFFFFF), Color(hex: 0xEDEDF2)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Time Strip")
                .font(.system(size: 28, weight: .bold))
            Text("See time zones as day-and-night ribbons, aligned to the same moment.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The real widget content + material, floating (shadow + rim) on a muted "desktop" panel so
    /// it reads as a placed widget. Renders the snapshot captured at launch (a static preview — the
    /// onboarding window is transient, so it doesn't tick). The inner `padding` reproduces
    /// WidgetKit's content margins — without it the ribbon scales to the full tile width and its
    /// rail labels touch (and clip at) the edges.
    private var hero: some View {
        WidgetRibbonView(snapshot: snapshot, maxRows: 4)
            .padding(14)
            .frame(width: 348, height: 164)   // ≈ the wide, short .systemMedium tile
            .background(WidgetBackground(scheme: scheme))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(dark ? 0.10 : 0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(dark ? 0.55 : 0.22), radius: 18, x: 0, y: 10)
            .padding(26)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous).fill(wallpaper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(.white.opacity(dark ? 0.06 : 0.4), lineWidth: 1)
            )
            .frame(maxWidth: .infinity)   // center the framed widget in the column
    }

    /// A soft desktop-wallpaper gradient (muted, echoing the ribbon palette) for the widget to
    /// float on.
    private var wallpaper: LinearGradient {
        LinearGradient(
            colors: dark
                ? [Color(hex: 0x243056), Color(hex: 0x342A4E), Color(hex: 0x3E2E2C)]
                : [Color(hex: 0xCBD6F2), Color(hex: 0xE4D8EE), Color(hex: 0xF6E2CE)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Add the widget")
                .font(.system(size: 15, weight: .semibold))
            Step(number: 1, text: "Open **Notification Center** (or right-click the desktop) and click **Edit Widgets**.")
            Step(number: 2, text: "Find **Time Strip** and add it at the **Medium** size.")
            Step(number: 3, text: "Right-click the widget, choose **Edit Widget**, and pick your cities.")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(dark ? Color(hex: 0x2A2A30) : Color(hex: 0xFFFFFF))
                .shadow(color: .black.opacity(dark ? 0.3 : 0.06), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(dark ? 0.06 : 0), lineWidth: 1)
        )
    }
}

/// A numbered step: a filled index badge beside markdown-formatted instructional text.
private struct Step: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 13) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [Color(hex: 0x0A84FF), Color(hex: 0x0060DF)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                )
                .shadow(color: Color(hex: 0x0A84FF).opacity(0.4), radius: 3, y: 1)
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
