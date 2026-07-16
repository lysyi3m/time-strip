import SwiftUI
import AppKit

@main
struct TimeStripApp: App {
    var body: some Scene {
        Window("Time Strip", id: "main") {
            OnboardingView()
        }
        // The window sizes to the onboarding content — there's nothing to resize into.
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Time Strip") { showAboutPanel() }
            }
        }
    }
}

/// Standard About panel (icon / name / version / copyright) plus a centered credits block with a
/// clickable link to the project repo.
@MainActor
private func showAboutPanel() {
    let credits = NSMutableAttributedString(
        string: "Many time zones at a glance — day/night ribbons aligned to the same moment.\n\n",
        attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
    )
    credits.append(NSAttributedString(
        string: "github.com/lysyi3m/time-strip",
        attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .link: URL(string: "https://github.com/lysyi3m/time-strip")!,
        ]
    ))
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center
    credits.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: credits.length))

    NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    NSApp.activate(ignoringOtherApps: true)
}
