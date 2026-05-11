import Foundation
import Combine

/// Analyzes posture snapshots and generates coaching tips
@MainActor
final class PostureCoach: ObservableObject {
    @Published var isPersonVisible = false
    @Published var currentPosture: String = "Good"

    /// Publisher for generated tips
    let tipSubject = PassthroughSubject<CoachingTip, Never>()

    private var cancellables = Set<AnyCancellable>()
    private let videoService: VideoAnalysisService

    // Sustained condition tracking (condition must persist for duration before tip fires)
    private var slouchStart: Date?
    private var lookAwayStart: Date?
    private var noSmileStart: Date?
    private var headTiltStart: Date?
    private var tooCloseStart: Date?
    private var tooFarStart: Date?

    // Duration thresholds (seconds a condition must persist)
    var slouchDuration: TimeInterval = 3
    var lookAwayDuration: TimeInterval = 3
    var noSmileDuration: TimeInterval = 5
    var headTiltDuration: TimeInterval = 3
    var distanceDuration: TimeInterval = 3

    // Smoothing: track consecutive frames for each condition to avoid flickering
    private var slouchFrames = 0
    private var lookAwayFrames = 0
    private var headTiltFrames = 0
    private let stableFrameThreshold = 4 // ~1.2s at 3fps before changing displayed posture

    // Track current displayed state to avoid unnecessary updates
    private var lastPosture: String = "Good"

    init(videoService: VideoAnalysisService) {
        self.videoService = videoService
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        videoService.snapshotSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.analyze(snapshot)
            }
            .store(in: &cancellables)
    }

    private func analyze(_ snapshot: PostureSnapshot) {
        isPersonVisible = snapshot.personDetected
        guard snapshot.personDetected else {
            resetTracking()
            updatePosture("Good")
            return
        }

        let now = snapshot.timestamp

        // Update frame counters for smoothing
        slouchFrames = snapshot.isSlouching ? slouchFrames + 1 : 0
        lookAwayFrames = snapshot.isLookingAway ? lookAwayFrames + 1 : 0
        headTiltFrames = snapshot.hasHeadTilt ? headTiltFrames + 1 : 0

        // Determine displayed posture based on sustained conditions only
        var newPosture = "Good"
        if slouchFrames >= stableFrameThreshold {
            newPosture = "Slouching"
        } else if lookAwayFrames >= stableFrameThreshold {
            newPosture = "Looking away"
        } else if headTiltFrames >= stableFrameThreshold {
            newPosture = "Head tilted"
        }
        updatePosture(newPosture)

        // Tip generation (uses separate sustained timers, independent of display)
        // Note: slouching tip removed — the Posture badge already shows slouching status

        checkCondition(
            isActive: snapshot.isLookingAway,
            start: &lookAwayStart,
            now: now,
            threshold: lookAwayDuration,
            tipType: .notLookingAtCamera,
            message: "Look at the camera to maintain eye contact",
            severity: .suggestion
        )

        checkCondition(
            isActive: !snapshot.isSmiling,
            start: &noSmileStart,
            now: now,
            threshold: noSmileDuration,
            tipType: .notSmiling,
            message: "Try smiling — it helps build rapport",
            severity: .info
        )

        checkCondition(
            isActive: snapshot.hasHeadTilt,
            start: &headTiltStart,
            now: now,
            threshold: headTiltDuration,
            tipType: .headTilt,
            message: "Level your head — it's tilting to one side",
            severity: .info
        )

        checkCondition(
            isActive: snapshot.isTooClose,
            start: &tooCloseStart,
            now: now,
            threshold: distanceDuration,
            tipType: .tooClose,
            message: "Move back — your shoulders and upper chest should be visible",
            severity: .suggestion
        )

        checkCondition(
            isActive: snapshot.isTooFar,
            start: &tooFarStart,
            now: now,
            threshold: distanceDuration,
            tipType: .tooFar,
            message: "Move closer to the camera",
            severity: .suggestion
        )
    }

    /// Only publish posture changes when the value actually differs
    private func updatePosture(_ newPosture: String) {
        if newPosture != lastPosture {
            lastPosture = newPosture
            currentPosture = newPosture
        }
    }

    private func emit(_ tip: CoachingTip) {
        guard UserDefaults.standard.object(forKey: "showPostureTips") as? Bool ?? true else { return }
        tipSubject.send(tip)
    }

    private func checkCondition(
        isActive: Bool,
        start: inout Date?,
        now: Date,
        threshold: TimeInterval,
        tipType: TipType,
        message: String,
        severity: TipSeverity
    ) {
        if isActive {
            if start == nil {
                start = now
            } else if now.timeIntervalSince(start!) > threshold {
                emit(CoachingTip(
                    type: tipType,
                    message: message,
                    severity: severity
                ))
                start = now // Reset to avoid continuous firing
            }
        } else {
            start = nil
        }
    }

    private func resetTracking() {
        slouchStart = nil
        lookAwayStart = nil
        noSmileStart = nil
        headTiltStart = nil
        tooCloseStart = nil
        tooFarStart = nil
        slouchFrames = 0
        lookAwayFrames = 0
        headTiltFrames = 0
    }

    func reset() {
        resetTracking()
        isPersonVisible = false
        lastPosture = "Good"
        currentPosture = "Good"
    }
}
