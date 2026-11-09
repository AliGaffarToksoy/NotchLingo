import XCTest
@testable import NotchLingoCore

final class SessionPlannerTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    func candidate(_ state: CardState, track: Track = .everyday, offset: Double = 0) -> StudyCandidate {
        var schedule = ReviewSchedule(); schedule.state = state; schedule.due = now.addingTimeInterval(offset)
        return StudyCandidate(id: UUID(), track: track, schedule: schedule)
    }
    func testDueReviewsBeforeNewAndNoFutureReviews() {
        let fresh = candidate(.new), review = candidate(.review), future = candidate(.review, offset: 1)
        let queue = SessionPlanner().queue([fresh, future, review], at: now, budget: DailyBudget())
        XCTAssertEqual(queue.map(\.id), [review.id, fresh.id])
    }
    func testShortStepsBypassExhaustedDailyCaps() {
        let learning = candidate(.learning), relearning = candidate(.relearning)
        let queue = SessionPlanner().queue([candidate(.new), candidate(.review), learning, relearning,
                                           candidate(.learning, offset: 1)], at: now,
                                          budget: DailyBudget(newLimit: 0, reviewLimit: 0))
        XCTAssertEqual(Set(queue.map(\.id)), Set([learning.id, relearning.id]))
    }
    func testRemainingBudgets() {
        let cards = (0..<10).map { _ in candidate(.new) } + (0..<10).map { _ in candidate(.review) }
        let queue = SessionPlanner().queue(cards, at: now,
            budget: DailyBudget(newLimit: 5, reviewLimit: 8, introducedToday: 3, reviewedToday: 5))
        XCTAssertEqual(queue.filter { $0.schedule.state == .new }.count, 2)
        XCTAssertEqual(queue.filter { $0.schedule.state == .review }.count, 3)
    }
    func testSeventyThirtyBalanceAndDeterminism() {
        let cards = (0..<20).map { _ in candidate(.new) } + (0..<20).map { _ in candidate(.new, track: .techWork) }
        let planner = SessionPlanner()
        let queue = planner.queue(cards, at: now, budget: DailyBudget(), everydayWeight: 0.7)
        XCTAssertEqual(queue.filter { $0.track == .everyday }.count, 7)
        XCTAssertEqual(queue.filter { $0.track == .techWork }.count, 3)
        XCTAssertEqual(queue.map(\.id), planner.queue(cards.reversed(), at: now, budget: DailyBudget(), everydayWeight: 0.7).map(\.id))
    }
    func testUnavailableTrackFallsBackAndZeroWeightDisables() {
        let cards = (0..<10).map { _ in candidate(.new, track: .techWork) }
        XCTAssertEqual(SessionPlanner().queue(cards, at: now, budget: DailyBudget()).count, 10)
        XCTAssertTrue(SessionPlanner().queue(cards, at: now, budget: DailyBudget(), everydayWeight: 1).isEmpty)
    }
}
