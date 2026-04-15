import XCTest
@testable import CueBud

final class PostureCoachTests: XCTestCase {

    func testPostureSnapshotSlouching() {
        let snapshot = PostureSnapshot(
            timestamp: Date(),
            shoulderNoseRatio: 0.10,
            gazeHorizontalOffset: 0,
            gazeVerticalOffset: 0,
            smileConfidence: 0.5,
            headTiltDegrees: 0,
            faceSizeFraction: 0.25,
            faceVerticalCenter: 0.6,
            personDetected: true
        )

        XCTAssertTrue(snapshot.isSlouching)
        XCTAssertFalse(snapshot.isLookingAway)
        XCTAssertTrue(snapshot.isSmiling)
        XCTAssertFalse(snapshot.hasHeadTilt)
        XCTAssertFalse(snapshot.isTooClose)
        XCTAssertFalse(snapshot.isTooFar)
    }

    func testPostureSnapshotSlouchingFallback() {
        // No shoulder data, but face is low in frame
        let snapshot = PostureSnapshot(
            timestamp: Date(),
            shoulderNoseRatio: nil,
            gazeHorizontalOffset: 0,
            gazeVerticalOffset: 0,
            smileConfidence: 0.5,
            headTiltDegrees: 0,
            faceSizeFraction: 0.20,
            faceVerticalCenter: 0.35,
            personDetected: true
        )

        XCTAssertTrue(snapshot.isSlouching)
    }

    func testPostureSnapshotGoodPosture() {
        let snapshot = PostureSnapshot(
            timestamp: Date(),
            shoulderNoseRatio: 0.25,
            gazeHorizontalOffset: 0.02,
            gazeVerticalOffset: 0.01,
            smileConfidence: 0.6,
            headTiltDegrees: 3,
            faceSizeFraction: 0.20,
            faceVerticalCenter: 0.65,
            personDetected: true
        )

        XCTAssertFalse(snapshot.isSlouching)
        XCTAssertFalse(snapshot.isLookingAway)
        XCTAssertTrue(snapshot.isSmiling)
        XCTAssertFalse(snapshot.hasHeadTilt)
        XCTAssertFalse(snapshot.isTooClose)
        XCTAssertFalse(snapshot.isTooFar)
    }

    func testPostureSnapshotLookingAway() {
        let snapshot = PostureSnapshot(
            timestamp: Date(),
            shoulderNoseRatio: 0.25,
            gazeHorizontalOffset: 0.3,
            gazeVerticalOffset: 0.0,
            smileConfidence: nil,
            headTiltDegrees: nil,
            faceSizeFraction: nil,
            faceVerticalCenter: nil,
            personDetected: true
        )

        XCTAssertTrue(snapshot.isLookingAway)
    }

    func testPostureSnapshotTooClose() {
        let snapshot = PostureSnapshot(
            timestamp: Date(),
            shoulderNoseRatio: nil,
            gazeHorizontalOffset: nil,
            gazeVerticalOffset: nil,
            smileConfidence: nil,
            headTiltDegrees: nil,
            faceSizeFraction: 0.6,
            faceVerticalCenter: 0.6,
            personDetected: true
        )

        XCTAssertTrue(snapshot.isTooClose)
        XCTAssertFalse(snapshot.isTooFar)
    }

    func testPostureSnapshotTooFar() {
        let snapshot = PostureSnapshot(
            timestamp: Date(),
            shoulderNoseRatio: nil,
            gazeHorizontalOffset: nil,
            gazeVerticalOffset: nil,
            smileConfidence: nil,
            headTiltDegrees: nil,
            faceSizeFraction: 0.05,
            faceVerticalCenter: 0.6,
            personDetected: true
        )

        XCTAssertFalse(snapshot.isTooClose)
        XCTAssertTrue(snapshot.isTooFar)
    }

    func testPostureSnapshotHeadTilt() {
        let snapshot = PostureSnapshot(
            timestamp: Date(),
            shoulderNoseRatio: 0.25,
            gazeHorizontalOffset: 0,
            gazeVerticalOffset: 0,
            smileConfidence: 0.5,
            headTiltDegrees: 20,
            faceSizeFraction: 0.25,
            faceVerticalCenter: 0.6,
            personDetected: true
        )

        XCTAssertTrue(snapshot.hasHeadTilt)
    }

    func testPostureSnapshotNoPersonDetected() {
        let snapshot = PostureSnapshot(
            timestamp: Date(),
            shoulderNoseRatio: nil,
            gazeHorizontalOffset: nil,
            gazeVerticalOffset: nil,
            smileConfidence: nil,
            headTiltDegrees: nil,
            faceSizeFraction: nil,
            faceVerticalCenter: nil,
            personDetected: false
        )

        XCTAssertFalse(snapshot.isSlouching)
        XCTAssertFalse(snapshot.isLookingAway)
        // nil smileConfidence defaults to true (benefit of the doubt)
        XCTAssertTrue(snapshot.isSmiling)
    }

    @MainActor
    func testPostureCoachReset() {
        let videoService = VideoAnalysisService()
        let coach = PostureCoach(videoService: videoService)

        coach.reset()

        XCTAssertFalse(coach.isPersonVisible)
        XCTAssertEqual(coach.currentPosture, "Good")
    }
}
