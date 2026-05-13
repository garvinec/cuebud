import SwiftUI

// MARK: - App

@main
struct CueBudApp: App {
    @StateObject private var auth: AuthService
    @StateObject private var permissions: PermissionsManager
    @StateObject private var subscriptionManager: SubscriptionManager
    @StateObject private var sessionVM: SessionViewModel
    @StateObject private var overlayVM: OverlayViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

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
        let authService = AuthService()
        let permissionsManager = PermissionsManager()
        let subManager = SubscriptionManager(auth: authService)
        let session = SessionViewModel(subscriptionManager: subManager)
        let overlay = OverlayViewModel(session: session)

        _auth = StateObject(wrappedValue: authService)
        _permissions = StateObject(wrappedValue: permissionsManager)
        _subscriptionManager = StateObject(wrappedValue: subManager)
        _sessionVM = StateObject(wrappedValue: session)
        _overlayVM = StateObject(wrappedValue: overlay)
    }

    var body: some Scene {
        // Floating overlay window
        Window("CueBud", id: "overlay") {
            Group {
                if auth.currentUser == nil {
                    LoginView(auth: auth)
                        .onAppear { configureOverlayWindow() }
                } else if !hasCompletedOnboarding {
                    OnboardingView(permissions: permissions) {
                        hasCompletedOnboarding = true
                    }
                    .onAppear { configureOverlayWindow() }
                } else if !subscriptionManager.canStartSession {
                    UpgradeView()
                        .environmentObject(subscriptionManager)
                        .onAppear { configureOverlayWindow() }
                } else {
                    OverlayView(overlayVM: overlayVM, sessionVM: sessionVM)
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

        // Session summary
        Window("Session Summary", id: "summary") {
            if sessionVM.showSummary {
                SessionSummaryView(
                    metrics: sessionVM.metrics,
                    sessionsRemaining: subscriptionManager.sessionsRemaining
                ) {
                    sessionVM.showSummary = false
                }
            }
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)

        // Settings
        Settings {
            SettingsView()
                .environmentObject(auth)
                .environmentObject(subscriptionManager)
        }

        // Feedback
        Window("Feedback", id: "feedback") {
            FeedbackView()
                .environmentObject(auth)
        }
        .windowResizability(.contentSize)

        // Menu bar
        MenuBarExtra("CueBud", image: "MenuBarIcon") {
            MenuBarView(sessionVM: sessionVM)
                .environmentObject(auth)
                .environmentObject(subscriptionManager)
        }
    }

    private func configureOverlayWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let window = NSApplication.shared.windows.first(where: { $0.title == "CueBud" || $0.identifier?.rawValue == "overlay" }),
                  let screen = NSScreen.main else { return }
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isMovableByWindowBackground = true
            window.hidesOnDeactivate = false

            // Snap to top-right, just below the menu bar.
            let sf = screen.visibleFrame
            let wf = window.frame
            window.setFrameOrigin(NSPoint(x: sf.maxX - wf.width, y: sf.maxY - wf.height))
        }
    }
}

// MARK: - Menu bar view

struct MenuBarView: View {
    @ObservedObject var sessionVM: SessionViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack {
            if auth.currentUser != nil {
                if sessionVM.isSessionActive {
                    Button("Stop Session (\(sessionVM.formattedDuration))") {
                        sessionVM.stopSession()
                    }
                } else if subscriptionManager.canStartSession {
                    Button("Start Session") {
                        sessionVM.startSession()
                    }
                } else {
                    Button("Upgrade to Start") {}
                        .disabled(true)
                }
                Divider()
                Button("Send Feedback...") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "feedback")
                }
                Divider()
            }

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

            if auth.currentUser != nil {
                Divider()
                Button("Sign Out") {
                    auth.signOut()
                }
            }

            Divider()

            Button("Quit CueBud") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
