import SwiftUI

@main
struct CueBudApp: App {
    @StateObject private var auth = AuthService()

    init() {
        UserDefaults.standard.register(defaults: [
            "maxFillersPerMinute": 3,
            "maxWPM": 170.0,
            "minWPM": 100.0,
            "ramblingThreshold": 90.0,
            "tipCooldown": 90.0,
            "showSpeechTips": true,
            "showPostureTips": true,
        ])
    }
    @StateObject private var permissions = PermissionsManager()
    @StateObject private var sessionVM = SessionViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        // Floating overlay window
        Window("CueBud", id: "overlay") {
            Group {
                if auth.currentUser == nil {
                    LoginView(auth: auth)
                } else if !hasCompletedOnboarding {
                    OnboardingView(permissions: permissions) {
                        hasCompletedOnboarding = true
                    }
                    .onAppear { configureOverlayWindow() }
                } else {
                    OverlayView(
                        overlayVM: OverlayViewModel(session: sessionVM),
                        sessionVM: sessionVM
                    )
                    .onAppear { configureOverlayWindow() }
                }
            }
            .task { auth.refreshSessionInBackground() }
            .onOpenURL { url in auth.handleCallbackURL(url) }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
                if let w = note.object as? NSWindow, w.title == "Settings" {
                    w.level = .floating
                }
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
                .environmentObject(auth)
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
                window.hidesOnDeactivate = false
            }
        }
    }
}

/// Menu bar dropdown with quick controls
struct MenuBarView: View {
    @ObservedObject var sessionVM: SessionViewModel
    @Environment(\.openSettings) private var openSettings

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
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let w = NSApp.windows.first(where: { $0.title == "Settings" }) {
                        w.level = .floating
                        w.makeKeyAndOrderFront(nil)
                    }
                }
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
