import AppKit
import AVFoundation
import Speech
import Combine

/// Manages camera, microphone, and speech recognition permissions
@MainActor
final class PermissionsManager: ObservableObject {
    @Published var cameraStatus: AVAuthorizationStatus = .notDetermined
    @Published var microphoneStatus: AVAuthorizationStatus = .notDetermined
    @Published var speechStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    var allGranted: Bool {
        cameraStatus == .authorized &&
        microphoneStatus == .authorized &&
        speechStatus == .authorized
    }

    var anyDenied: Bool {
        cameraStatus == .denied || cameraStatus == .restricted ||
        microphoneStatus == .denied || microphoneStatus == .restricted ||
        speechStatus == .denied || speechStatus == .restricted
    }

    init() {
        refreshStatuses()
    }

    func refreshStatuses() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        speechStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestAllPermissions() async {
        await requestCameraPermission()
        await requestMicrophonePermission()
        await requestSpeechPermission()
    }

    func requestCameraPermission() async {
        if cameraStatus == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraStatus = granted ? .authorized : .denied
        }
    }

    func requestMicrophonePermission() async {
        if microphoneStatus == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphoneStatus = granted ? .authorized : .denied
        }
    }

    func requestSpeechPermission() async {
        if speechStatus == .notDetermined {
            speechStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        }
    }

    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }
}
