import AVFoundation
import Speech
import Combine

/// Manages AVAudioEngine + SFSpeechRecognizer pipeline with session recycling
@MainActor
final class AudioAnalysisService: ObservableObject {
    @Published var isRunning = false
    @Published var currentTranscript = ""
    @Published var currentVolume: Float = -160

    let levelMeter = AudioLevelMeter()
    let paceCalculator = SpeechPaceCalculator()

    /// Publisher for new speech segments
    let segmentSubject = PassthroughSubject<SpeechSegment, Never>()
    /// Publisher for real-time partial transcript updates
    let partialTranscriptSubject = PassthroughSubject<String, Never>()

    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var sessionStartTime: Date?
    private var sessionTimer: Timer?
    private var lastTranscriptLength = 0
    private var accumulatedTranscript = ""

    // Session recycling interval (Apple limit is ~60s)
    private let sessionRecycleInterval: TimeInterval = 55

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func start() {
        guard !isRunning else { return }

        audioEngine = AVAudioEngine()
        guard let audioEngine else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap for audio level metering
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.levelMeter.process(buffer: buffer)

            // Feed buffer to speech recognizer
            self.recognitionRequest?.append(buffer)

            // Update volume on main thread
            let level = self.levelMeter.currentLevel
            Task { @MainActor in
                self.currentVolume = level
            }
        }

        do {
            try audioEngine.start()
            isRunning = true
            startRecognitionSession()
            scheduleSessionRecycle()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }

    func stop() {
        isRunning = false
        sessionTimer?.invalidate()
        sessionTimer = nil
        stopRecognitionSession()

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        paceCalculator.reset()
        currentTranscript = ""
        accumulatedTranscript = ""
    }

    // MARK: - Speech Recognition Session Management

    private func startRecognitionSession() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true

        sessionStartTime = Date()
        lastTranscriptLength = 0

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let transcript = result.bestTranscription.formattedString

                Task { @MainActor in
                    self.currentTranscript = transcript
                    self.partialTranscriptSubject.send(transcript)

                    // Calculate new words since last update
                    let newWordCount = transcript.split(separator: " ").count -
                        self.lastTranscriptLength
                    if newWordCount > 0 {
                        self.paceCalculator.recordWords(newWordCount)
                        self.lastTranscriptLength = transcript.split(separator: " ").count
                    }
                }

                if result.isFinal {
                    Task { @MainActor in
                        self.finalizeSegment(transcript: transcript)
                    }
                }
            }

            if error != nil {
                // Session ended (timeout or error) — will be recycled by timer
            }
        }
    }

    private func stopRecognitionSession() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }

    private func scheduleSessionRecycle() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: sessionRecycleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recycleSession()
            }
        }
    }

    private func recycleSession() {
        guard isRunning else { return }

        // Finalize current transcript
        let currentText = currentTranscript
        if !currentText.isEmpty {
            finalizeSegment(transcript: currentText)
        }

        // Stop old session and start new one
        stopRecognitionSession()
        startRecognitionSession()
    }

    private func finalizeSegment(transcript: String) {
        guard !transcript.isEmpty else { return }

        let duration = Date().timeIntervalSince(sessionStartTime ?? Date())
        let segment = SpeechSegment(
            text: transcript,
            timestamp: sessionStartTime ?? Date(),
            duration: duration,
            averageVolume: currentVolume
        )

        accumulatedTranscript += " " + transcript
        segmentSubject.send(segment)
    }
}
