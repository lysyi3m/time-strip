import SwiftUI

@main
struct TimeStripApp: App {
    var body: some Scene {
        Window("Time Strip", id: "main") {
            OnboardingView()
        }
        // The window sizes to the onboarding content — there's nothing to resize into.
        .windowResizability(.contentSize)
    }
}
