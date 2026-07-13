import SwiftUI
import TimeStripKit
import TimeStripUI

// Acceptance surface for Phase 4: verify against the mocks across 2–5 rows, 12/24h,
// boundary/none, light/dark. Confirm the boundary notch does NOT shift column centers.

private func ribbonPreview(_ snapshot: RibbonSnapshot, is12h: Bool, scheme: ColorScheme) -> some View {
    RibbonView(snapshot: snapshot, is12h: is12h, locale: is12h ? Locale(identifier: "en_US") : Locale(identifier: "pl_PL"))
        .padding(16)
        .background(scheme == .dark ? Color.black : Color.white)
        .environment(\.colorScheme, scheme)
        .preferredColorScheme(scheme)
}

#Preview("2 rows · 24h · light") {
    ribbonPreview(RibbonFixtures.twoRows, is12h: false, scheme: .light)
}

#Preview("3 rows · 12h · light") {
    ribbonPreview(RibbonFixtures.threeRows, is12h: true, scheme: .light)
}

#Preview("4 rows · 24h · dark") {
    ribbonPreview(RibbonFixtures.fourRows, is12h: false, scheme: .dark)
}

#Preview("5 rows · 12h · dark") {
    ribbonPreview(RibbonFixtures.fiveRows, is12h: true, scheme: .dark)
}

#Preview("boundary · 24h · light") {
    ribbonPreview(RibbonFixtures.twoRows, is12h: false, scheme: .light)
}

#Preview("no boundary · 24h · dark") {
    ribbonPreview(RibbonFixtures.noBoundary, is12h: false, scheme: .dark)
}
