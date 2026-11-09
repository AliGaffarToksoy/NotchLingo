import XCTest
@testable import NotchLingoCore

final class SRSTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let engine = SRSEngine()

    func testAgainGoodGoodUsesMinuteTenMinutesThenDay() {
        let failed = engine.rate(ReviewSchedule(), as: .again, at: now)
        XCTAssertEqual(failed.state, .learning)
        XCTAssertEqual(failed.due.timeIntervalSince(now), 60)
        let second = engine.rate(failed, as: .good, at: failed.due)
        XCTAssertEqual(second.due.timeIntervalSince(failed.due), 600)
        let graduated = engine.rate(second, as: .good, at: second.due)
        XCTAssertEqual(graduated.state, .review)
        XCTAssertEqual(graduated.due.timeIntervalSince(second.due), 86400)
    }
    func testFirstGoodDoesNotSkipLearning() {
        let result = engine.rate(ReviewSchedule(), as: .good, at: now)
        XCTAssertEqual(result.state, .learning)
        XCTAssertEqual(result.due.timeIntervalSince(now), 600)
    }
    func testEasyGraduatesImmediately() {
        let result = engine.rate(ReviewSchedule(), as: .easy, at: now)
        XCTAssertEqual(result.state, .review)
        XCTAssertEqual(result.intervalDays, 4)
    }
    func testHardRepeatsCurrentLearningStep() {
        var result = engine.rate(ReviewSchedule(), as: .hard, at: now)
        XCTAssertEqual(result.learningStep, 0)
        XCTAssertEqual(result.due.timeIntervalSince(now), 360)
        result = engine.rate(result, as: .good, at: now)
        result = engine.rate(result, as: .hard, at: now)
        XCTAssertEqual(result.learningStep, 1)
        XCTAssertEqual(result.due.timeIntervalSince(now), 600)
    }
    func testReviewRatingsHaveIncreasingIntervals() {
        var old = ReviewSchedule(); old.state = .review; old.intervalDays = 20
        let hard = engine.rate(old, as: .hard, at: now)
        let good = engine.rate(old, as: .good, at: now)
        let easy = engine.rate(old, as: .easy, at: now)
        XCTAssertEqual(hard.intervalDays, 24)
        XCTAssertEqual(good.intervalDays, 50)
        XCTAssertGreaterThan(easy.intervalDays, good.intervalDays)
        XCTAssertTrue(good.isMature)
    }
    func testLapseReturnsSoonAndRetainsReducedInterval() {
        var old = ReviewSchedule(); old.state = .review; old.intervalDays = 20
        var result = engine.rate(old, as: .again, at: now)
        XCTAssertEqual(result.state, .relearning)
        XCTAssertEqual(result.lapses, 1)
        XCTAssertEqual(result.intervalDays, 10)
        XCTAssertEqual(result.due.timeIntervalSince(now), 60)
        result = engine.rate(result, as: .again, at: result.due)
        XCTAssertEqual(result.lapses, 1, "Repeated learning failures are misses, not new review lapses")
        result = engine.rate(result, as: .good, at: result.due)
        result = engine.rate(result, as: .good, at: result.due)
        XCTAssertEqual(result.state, .review)
        XCTAssertEqual(result.intervalDays, 10)
    }
    func testLeechThresholdAndEaseFloor() {
        var result = ReviewSchedule()
        for _ in 0..<8 { result = engine.rate(result, as: .again, at: now) }
        XCTAssertTrue(result.isLeech)
        for _ in 0..<20 {
            result.state = .review
            result = engine.rate(result, as: .again, at: now)
        }
        XCTAssertEqual(result.ease, 1.3)
    }
    func testDueIsBasedOnAnswerTime() {
        let tomorrow = now.addingTimeInterval(86400)
        let result = engine.rate(ReviewSchedule(), as: .again, at: tomorrow)
        XCTAssertEqual(result.due, tomorrow.addingTimeInterval(60))
        XCTAssertEqual(result.lastReviewed, tomorrow)
    }
}
