import Foundation
import AVFoundation
import Speech
import Combine

/// Manages session lifecycle and aggregated metrics
@MainActor
final class SessionViewModel: ObservableObject {
    @Published var isSessionActive = false
    /// True while awaiting microphone/speech permission — blocks duplicate start attempts.
    @Published var isRequestingPermissions = false
    @Published var metrics = SessionMetrics()
    @Published var sessionDuration: TimeInterval = 0
    @Published var showSummary = false

    private var cancellables = Set<AnyCancellable>()
    private var durationTimer: Timer?

    let audioService: AudioAnalysisService
    let videoService: VideoAnalysisService
    let speechCoach: SpeechCoach
    let postureCoach: PostureCoach
    let tipEngine: TipEngine
    private let subscriptionManager: SubscriptionManager

    init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
        audioService = AudioAnalysisService()
        videoService = VideoAnalysisService()
        speechCoach = SpeechCoach(audioService: audioService)
        postureCoach = PostureCoach(videoService: videoService)
        tipEngine = TipEngine()

        setupTipEngineSubscriptions()
        setupMetricsTracking()
    }

    private func setupTipEngineSubscriptions() {
        tipEngine.subscribe(to: speechCoach.tipSubject.eraseToAnyPublisher())
        tipEngine.subscribe(to: postureCoach.tipSubject.eraseToAnyPublisher())
    }

    private func setupMetricsTracking() {
        // Track tips shown
        tipEngine.displayTipSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tip in
                self?.metrics.recordTip(tip)
            }
            .store(in: &cancellables)

        // Track speech metrics from segments
        audioService.segmentSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] segment in
                guard let self else { return }
                self.metrics.totalWordsSpoken += segment.wordCount
                self.metrics.totalSpeakingDuration += segment.duration

                let fillers = FillerWordDetector.count(in: segment.text)
                self.metrics.fillerWordCount += fillers
            }
            .store(in: &cancellables)

        // Track posture metrics
        videoService.snapshotSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                let interval: TimeInterval = 0.3 // ~3fps

                if snapshot.isSlouching {
                    self.metrics.slouchingDuration += interval
                }
                if snapshot.isLookingAway {
                    self.metrics.notLookingAtCameraDuration += interval
                }
                if snapshot.isSmiling {
                    self.metrics.smilingDuration += interval
                }
            }
            .store(in: &cancellables)
    }

    func startSession() {
        guard !isSessionActive && !isRequestingPermissions else { return }
        isRequestingPermissions = true
        Task { await startSessionAfterPermissions() }
    }

    private func startSessionAfterPermissions() async {
        let micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        guard micGranted && isRequestingPermissions else {
            isRequestingPermissions = false
            return
        }

        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized && isRequestingPermissions else {
            isRequestingPermissions = false
            return
        }

        isRequestingPermissions = false
        metrics = SessionMetrics()
        isSessionActive = true
        showSummary = false

        audioService.start()
        videoService.start()
        tipEngine.startSession()

        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sessionDuration = self?.metrics.sessionDuration ?? 0
                self?.updateLiveMetrics()
            }
        }
    }

    func stopSession() {
        if isRequestingPermissions {
            // Cancel the in-flight permission request — startSessionAfterPermissions()
            // checks this flag before touching any services.
            isRequestingPermissions = false
            return
        }

        guard isSessionActive else { return }

        isSessionActive = false
        metrics.sessionEnd = Date()

        durationTimer?.invalidate()
        durationTimer = nil

        audioService.stop()
        videoService.stop()
        tipEngine.endSession()
        speechCoach.reset()
        postureCoach.reset()

        showSummary = true
        subscriptionManager.recordSessionCompleted()
    }

    func toggleSession() {
        if isSessionActive || isRequestingPermissions {
            stopSession()
        } else {
            startSession()
        }
    }

    private func updateLiveMetrics() {
        let wpm = audioService.paceCalculator.getWPM()
        if wpm > 0 {
            metrics.averageWPM = wpm
            if wpm > metrics.peakWPM {
                metrics.peakWPM = wpm
            }
        }
        metrics.averageVolume = audioService.levelMeter.currentLevel
    }

    var formattedDuration: String {
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
