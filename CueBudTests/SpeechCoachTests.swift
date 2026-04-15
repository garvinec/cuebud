import XCTest
@testable import CueBud

final class SpeechCoachTests: XCTestCase {

    @MainActor
    func testSpeechCoachInitialization() {
        let audioService = AudioAnalysisService()
        let coach = SpeechCoach(audioService: audioService)

        XCTAssertEqual(coach.recentFillerCount, 0)
        XCTAssertEqual(coach.currentWPM, 0)
        XCTAssertFalse(coach.isSpeaking)
    }

    @MainActor
    func testSpeechCoachReset() {
        let audioService = AudioAnalysisService()
        let coach = SpeechCoach(audioService: audioService)

        coach.reset()

        XCTAssertEqual(coach.recentFillerCount, 0)
        XCTAssertEqual(coach.currentWPM, 0)
        XCTAssertFalse(coach.isSpeaking)
    }

    @MainActor
    func testDefaultThresholds() {
        let audioService = AudioAnalysisService()
        let coach = SpeechCoach(audioService: audioService)

        XCTAssertEqual(coach.maxFillersPerMinute, 3)
        XCTAssertEqual(coach.maxWPM, 160)
        XCTAssertEqual(coach.minWPM, 140)
        XCTAssertEqual(coach.fastSpeechDuration, 7)
        XCTAssertEqual(coach.slowSpeechDuration, 7)
        XCTAssertEqual(coach.ramblingThreshold, 10)
        XCTAssertEqual(coach.ramblingPauseReset, 1)
    }
}
