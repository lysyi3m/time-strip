import SwiftUI

/// Shown in place of the ribbon when the widget doesn't have enough cities to be useful (fewer
/// than two configured). A comparison needs at least two zones, so rather than render a lone
/// ribbon we nudge the user into the editor. Sits on the same `WidgetBackground` as the ribbon.
public struct WidgetPromptView: View {
    @Environment(\.colorScheme) private var scheme

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 44, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Palette.railLabel(scheme))
            VStack(spacing: 4) {
                Text("Choose your cities")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.railLabel(scheme))
                Text("Right-click the widget and choose Edit Widget to add at least two time zones.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.railLabel(scheme).opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
