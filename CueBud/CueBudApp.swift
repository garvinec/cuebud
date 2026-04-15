import SwiftUI

@main
struct CueBudApp: App {
    @StateObject private var permissions = PermissionsManager()
    @StateObject private var sessionVM = SessionViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        // Floating overlay window
        Window("CueBud", id: "overlay") {
            Group {
                if hasCompletedOnboarding {
                    OverlayView(
                        overlayVM: OverlayViewModel(session: sessionVM),
                        sessionVM: sessionVM
                    )
                } else {
                    OnboardingView(permissions: permissions) {
                        hasCompletedOnboarding = true
                    }
                }
            }
            .onAppear {
                configureOverlayWindow()
            }
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)

        // Session summary window
        Window("Session Summary", id: "summary") {
            if sessionVM.showSummary {
                SessionSummaryView(metrics: sessionVM.metrics) {
                    sessionVM.showSummary = false
                }
            }
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)

        // Settings window
        Settings {
            SettingsView()
        }

        // Menu bar extra
        MenuBarExtra("CueBud", systemImage: "bubble.left.and.text.bubble.right") {
            MenuBarView(sessionVM: sessionVM)
        }
    }

    private func configureOverlayWindow() {
        // Configure window to float above all apps including fullscreen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let window = NSApplication.shared.windows.first(where: { $0.title == "CueBud" || $0.identifier?.rawValue == "overlay" }) {
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = false
                window.isMovableByWindowBackground = true

                // Keep it on top
                window.hidesOnDeactivate = false
            }
        }
    }
}

/// Menu bar dropdown with quick controls
struct MenuBarView: View {
    @ObservedObject var sessionVM: SessionViewModel

    var body: some View {
        VStack {
            if sessionVM.isSessionActive {
                Button("Stop Session (\(sessionVM.formattedDuration))") {
                    sessionVM.stopSession()
                }
            } else {
                Button("Start Session") {
                    sessionVM.startSession()
                }
            }

            Divider()

            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit CueBud") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
