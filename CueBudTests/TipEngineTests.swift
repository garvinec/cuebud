import XCTest
@testable import CueBud

final class TipEngineTests: XCTestCase {

    @MainActor
    func testWarmupBlocksTips() {
        let engine = TipEngine()
        engine.warmupDuration = 15
        engine.startSession()

        let tip = CoachingTip(type: .fillerWords, message: "Test", severity: .suggestion)
        engine.enqueue(tip)

        XCTAssertNil(engine.activeTip, "Tips should be blocked during warmup period")
    }

    @MainActor
    func testTipDisplayedAfterWarmup() {
        let engine = TipEngine()
        engine.warmupDuration = 0
        engine.startSession()

        let tip = CoachingTip(type: .fillerWords, message: "Reduce fillers", severity: .suggestion)
        engine.enqueue(tip)

        XCTAssertNotNil(engine.activeTip)
        XCTAssertEqual(engine.activeTip?.type, .fillerWords)
    }

    @MainActor
    func testCooldownPreventsRepeat() {
        let engine = TipEngine()
        engine.warmupDuration = 0
        engine.cooldownInterval = 90
        engine.startSession()

        let tip1 = CoachingTip(type: .fillerWords, message: "Test 1", severity: .suggestion)
        engine.enqueue(tip1)
        XCTAssertNotNil(engine.activeTip)

        // Dismiss and try same type again
        engine.userDismiss()

        let tip2 = CoachingTip(type: .fillerWords, message: "Test 2", severity: .suggestion)
        engine.enqueue(tip2)

        // Should be nil because cooldown hasn't elapsed
        XCTAssertNil(engine.activeTip)
    }

    @MainActor
    func testReEmitExtendsTip() {
        let engine = TipEngine()
        engine.warmupDuration = 0
        engine.startSession()

        let tip1 = CoachingTip(type: .slouching, message: "Sit up", severity: .suggestion)
        engine.enqueue(tip1)
        XCTAssertEqual(engine.activeTip?.type, .slouching)

        // Re-emit same type — should keep the tip active, not add to history
        let tip2 = CoachingTip(type: .slouching, message: "Sit up again", severity: .suggestion)
        engine.enqueue(tip2)

        XCTAssertEqual(engine.activeTip?.type, .slouching)
        XCTAssertEqual(engine.tipHistory.count, 1)
    }

    @MainActor
    func testPriorityOrdering() {
        let engine = TipEngine()
        engine.warmupDuration = 0
        engine.gracePeriod = 999
        engine.startSession()

        // Enqueue a low-priority tip first (it becomes active)
        let infoTip = CoachingTip(type: .notSmiling, message: "Smile", severity: .info)
        engine.enqueue(infoTip)

        // Enqueue higher priority while first is active — goes to queue
        let warningTip = CoachingTip(type: .tooQuiet, message: "Speak up", severity: .warning)
        engine.enqueue(warningTip)

        let suggestionTip = CoachingTip(type: .slouching, message: "Sit up", severity: .suggestion)
        engine.enqueue(suggestionTip)

        // First active tip should be the info one (it was first)
        XCTAssertEqual(engine.activeTip?.type, .notSmiling)
    }

    @MainActor
    func testDismissShowsNext() {
        let engine = TipEngine()
        engine.warmupDuration = 0
        engine.cooldownInterval = 0
        engine.startSession()

        let tip1 = CoachingTip(type: .fillerWords, message: "Fillers", severity: .suggestion)
        let tip2 = CoachingTip(type: .slouching, message: "Sit up", severity: .warning)

        engine.enqueue(tip1)
        engine.enqueue(tip2)

        XCTAssertEqual(engine.activeTip?.type, .fillerWords)
    }

    @MainActor
    func testEndSessionClearsState() {
        let engine = TipEngine()
        engine.warmupDuration = 0
        engine.startSession()

        let tip = CoachingTip(type: .fillerWords, message: "Test", severity: .suggestion)
        engine.enqueue(tip)

        engine.endSession()

        XCTAssertNil(engine.activeTip)
    }

    @MainActor
    func testTipHistory() {
        let engine = TipEngine()
        engine.warmupDuration = 0
        engine.cooldownInterval = 0
        engine.startSession()

        let tip = CoachingTip(type: .speakingTooFast, message: "Slow down", severity: .suggestion)
        engine.enqueue(tip)

        XCTAssertEqual(engine.tipHistory.count, 1)
        XCTAssertEqual(engine.tipHistory.first?.type, .speakingTooFast)
    }
}
