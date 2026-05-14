import SwiftUI

/// First-run onboarding: permission requests + brief tutorial
struct OnboardingView: View {
    @ObservedObject var permissions: PermissionsManager
    let onComplete: () -> Void

    @State private var currentStep = 0
    @State private var isRequestingPermissions = false

    var body: some View {
        VStack(spacing: 24) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color("AccentColor") : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            switch currentStep {
            case 0:
                welcomeStep
            case 1:
                permissionsStep
            case 2:
                readyStep
            default:
                EmptyView()
            }
        }
        .padding(32)
        .frame(width: 420, height: 380)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("LoginBackground"))
                .shadow(color: .black.opacity(0.15), radius: 24, y: 8)
        )
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 48))
                .foregroundColor(Color("AccentColor"))

            Text("Welcome to CueBud")
                .font(.title.weight(.bold))

            Text("Your real-time communication coach for video calls. CueBud watches and listens to give you subtle tips to improve your presence.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Spacer()

            Button("Get Started") {
                withAnimation { currentStep = 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var permissionsStep: some View {
        VStack(spacing: 16) {
            Text("Permissions")
                .font(.title2.weight(.bold))

            Text("CueBud needs access to your camera and microphone. All processing happens on-device — nothing leaves your Mac.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Analyze speech patterns",
                    status: permissions.microphoneStatus == .authorized ? .granted : .needed
                )
                PermissionRow(
                    icon: "camera.fill",
                    title: "Camera",
                    description: "Analyze posture & expressions",
                    status: permissions.cameraStatus == .authorized ? .granted : .needed
                )
                PermissionRow(
                    icon: "waveform",
                    title: "Speech Recognition",
                    description: "Detect filler words & pace",
                    status: permissions.speechStatus == .authorized ? .granted : .needed
                )
            }

            Spacer()

            Button("Grant Permissions") {
                isRequestingPermissions = true
                Task {
                    await permissions.requestAllPermissions()
                    isRequestingPermissions = false
                    if permissions.allGranted {
                        withAnimation { currentStep = 2 }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRequestingPermissions)

            if permissions.anyDenied {
                Button("Open System Settings") {
                    permissions.openSystemPreferences()
                }
                .font(.caption)
            }
        }
    }

    private var readyStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.title.weight(.bold))

            Text("CueBud will float above your video calls. Press Play to start a coaching session. Tips will appear as gentle reminders.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                TutorialItem(icon: "play.fill", text: "Tap Play to start coaching")
                TutorialItem(icon: "stop.fill", text: "Tap Stop to end and see summary")
                TutorialItem(icon: "chevron.up", text: "Collapse to compact mode")
            }
            .padding()

            Spacer()

            Button("Start Using CueBud") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

enum PermissionState {
    case needed, granted
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionState

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color("AccentColor"))
                .frame(width: 28)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: status == .granted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(status == .granted ? .green : .secondary)
        }
    }
}

struct TutorialItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(Color("AccentColor"))
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
        }
    }
}
