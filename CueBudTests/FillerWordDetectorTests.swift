import XCTest
@testable import CueBud

final class FillerWordDetectorTests: XCTestCase {

    func testDetectsUm() {
        let count = FillerWordDetector.count(in: "So um I was thinking about um the project")
        XCTAssertGreaterThanOrEqual(count, 2)
    }

    func testDetectsUh() {
        let count = FillerWordDetector.count(in: "Uh well uh I don't know")
        XCTAssertGreaterThanOrEqual(count, 2)
    }

    func testDetectsLike() {
        let count = FillerWordDetector.count(in: "It was like really like amazing")
        XCTAssertGreaterThanOrEqual(count, 2)
    }

    func testDetectsYouKnow() {
        let count = FillerWordDetector.count(in: "So you know it's important you know")
        XCTAssertGreaterThanOrEqual(count, 2)
    }

    func testDetectsBasically() {
        let count = FillerWordDetector.count(in: "Basically the whole thing is basically done")
        XCTAssertGreaterThanOrEqual(count, 2)
    }

    func testNoFillersInCleanSpeech() {
        let count = FillerWordDetector.count(in: "The quarterly report shows strong growth in all segments")
        XCTAssertEqual(count, 0)
    }

    func testEmptyString() {
        let count = FillerWordDetector.count(in: "")
        XCTAssertEqual(count, 0)
    }

    func testMixedFillers() {
        let text = "Um so basically I was like you know thinking about it"
        let count = FillerWordDetector.count(in: text)
        XCTAssertGreaterThanOrEqual(count, 3)
    }

    func testDetectReturnsMatches() {
        let matches = FillerWordDetector.detect(in: "Um I think uh that was good")
        XCTAssertGreaterThanOrEqual(matches.count, 2)

        let fillers = matches.map { $0.filler }
        XCTAssertTrue(fillers.contains("um"))
        XCTAssertTrue(fillers.contains("uh"))
    }

    func testCaseInsensitive() {
        let count = FillerWordDetector.count(in: "UM UH LIKE BASICALLY")
        XCTAssertGreaterThanOrEqual(count, 4)
    }
}
