import Foundation
import Combine

/// Analyzes speech patterns and generates coaching tips
@MainActor
final class SpeechCoach: ObservableObject {
    @Published var recentFillerCount = 0
    @Published var currentWPM: Double = 0
    @Published var isSpeaking = false

    /// Publisher for generated tips
    let tipSubject = PassthroughSubject<CoachingTip, Never>()

    private var cancellables = Set<AnyCancellable>()
    private let audioService: AudioAnalysisService

    // Filler tracking
    private var fillerCountInWindow = 0
    private var fillerWindowStart = Date()
    private let fillerWindowDuration: TimeInterval = 60
    private var lastCheckedTranscript = ""

    // Speech state
    private var continuousSpeechStart: Date?
    private var lastSpeechTime: Date?
    private var wasSpeaking = false
    private var fastSpeechStart: Date?
    private var slowSpeechStart: Date?

    // Thresholds
    var maxFillersPerMinute = 3
    var maxWPM: Double = 160
    var minWPM: Double = 140
    var fastSpeechDuration: TimeInterval = 7
    var slowSpeechDuration: TimeInterval = 7
    var ramblingThreshold: TimeInterval = 10
    var ramblingPauseReset: TimeInterval = 1
    var idealVolumeMin: Float = -12   // dB, ideal mic input range: -12 to -6
    var idealVolumeMax: Float = -6
    var quietThreshold: Float = -20   // dB, below this is genuinely too quiet

    init(audioService: AudioAnalysisService) {
        self.audioService = audioService
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        // Monitor partial transcripts for fillers + pace (every 1s, not 2s)
        audioService.partialTranscriptSubject
            .receive(on: DispatchQueue.main)
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] transcript in
                self?.analyzePartialTranscript(transcript)
            }
            .store(in: &cancellables)

        // Also check finalized segments for accurate filler count
        audioService.segmentSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] segment in
                self?.analyzeSegment(segment)
            }
            .store(in: &cancellables)

        // Monitor volume + speech state every second
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkVolume()
                self?.checkSpeechState()
                self?.checkPace()
            }
            .store(in: &cancellables)
    }

    private func analyzePartialTranscript(_ transcript: String) {
        // Check fillers in new text since last check
        let newText: String
        if transcript.count > lastCheckedTranscript.count {
            let startIdx = transcript.index(transcript.startIndex, offsetBy: lastCheckedTranscript.count)
            newText = String(transcript[startIdx...])
        } else {
            newText = transcript
        }
        lastCheckedTranscript = transcript

        if !newText.isEmpty {
            let fillers = FillerWordDetector.count(in: newText)
            if fillers > 0 {
                let now = Date()
                // Reset window if needed
                if now.timeIntervalSince(fillerWindowStart) > fillerWindowDuration {
                    fillerWindowStart = now
                    fillerCountInWindow = 0
                }
                fillerCountInWindow += fillers
                recentFillerCount = fillerCountInWindow

                if fillerCountInWindow > maxFillersPerMinute {
                    tipSubject.send(CoachingTip(
                        type: .fillerWords,
                        message: "Try to reduce filler words (\(fillerCountInWindow) in the last minute)",
                        severity: .suggestion
                    ))
                }
            }
        }
    }

    private func analyzeSegment(_ segment: SpeechSegment) {
        // Segments are finalized every ~55s — use for accurate counts
        // but partial transcript already handles real-time detection
    }

    /// Check pace from the pace calculator (runs every 1s via timer)
    private func checkPace() {
        let wpm = audioService.paceCalculator.getWPM()
        currentWPM = wpm

        let now = Date()

        // Speaking too fast
        if wpm > maxWPM {
            if fastSpeechStart == nil {
                fastSpeechStart = now
            } else if now.timeIntervalSince(fastSpeechStart!) > fastSpeechDuration {
                tipSubject.send(CoachingTip(
                    type: .speakingTooFast,
                    message: "Slow down — you're at \(Int(wpm)) words per minute",
                    severity: .suggestion
                ))
                fastSpeechStart = now
            }
        } else {
            fastSpeechStart = nil
        }

        // Speaking too slow
        if wpm > 0 && wpm < minWPM {
            if slowSpeechStart == nil {
                slowSpeechStart = now
            } else if now.timeIntervalSince(slowSpeechStart!) > slowSpeechDuration {
                tipSubject.send(CoachingTip(
                    type: .speakingTooSlow,
                    message: "Pick up the pace — you're at \(Int(wpm)) words per minute",
                    severity: .info
                ))
                slowSpeechStart = now
            }
        } else {
            slowSpeechStart = nil
        }
    }

    private func checkVolume() {
        guard audioService.isRunning else { return }

        let level = audioService.levelMeter.currentLevel

        // Detect speaking: any audio above silence threshold
        let speaking = level > -50

        isSpeaking = speaking

        // Too quiet: speaking detected but well below ideal volume range
        if speaking && level < quietThreshold {
            tipSubject.send(CoachingTip(
                type: .tooQuiet,
                message: "Speak up — your voice is hard to hear",
                severity: .warning
            ))
        }
    }

    private func checkSpeechState() {
        let now = Date()
        let speaking = isSpeaking

        if speaking {
            lastSpeechTime = now

            if continuousSpeechStart == nil {
                continuousSpeechStart = now
            }

            // Rambling detection
            if let start = continuousSpeechStart,
               now.timeIntervalSince(start) > ramblingThreshold {
                tipSubject.send(CoachingTip(
                    type: .rambling,
                    message: "You've been talking for \(Int(now.timeIntervalSince(start)))s — take a breath",
                    severity: .suggestion
                ))
                continuousSpeechStart = now
            }
        } else {
            if let lastSpeech = lastSpeechTime,
               now.timeIntervalSince(lastSpeech) > ramblingPauseReset {
                continuousSpeechStart = nil
            }
        }

        wasSpeaking = speaking
    }

    func reset() {
        fillerCountInWindow = 0
        fillerWindowStart = Date()
        recentFillerCount = 0
        currentWPM = 0
        continuousSpeechStart = nil
        lastSpeechTime = nil
        fastSpeechStart = nil
        slowSpeechStart = nil
        lastCheckedTranscript = ""
    }
}
