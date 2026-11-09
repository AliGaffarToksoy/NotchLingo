import XCTest
@testable import NotchLingoCore

final class StudyStatisticsTests: XCTestCase {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    func activity(dayOffset: Int, rating: Rating = .good, state: CardState = .review, id: UUID = UUID()) -> StudyActivity {
        StudyActivity(cardID: id, date: calendar.date(byAdding: .day, value: dayOffset, to: now)!,
                      rating: rating, previousState: state)
    }
    func testStreakTodayYesterdayGapAndFuture() {
        XCTAssertEqual(StudyStatistics.streak([activity(dayOffset: 0), activity(dayOffset: -1),
            activity(dayOffset: -1), activity(dayOffset: -2), activity(dayOffset: -4), activity(dayOffset: 1)],
            now: now, calendar: calendar), 3)
        XCTAssertEqual(StudyStatistics.streak([activity(dayOffset: -1)], now: now, calendar: calendar), 1)
        XCTAssertEqual(StudyStatistics.streak([activity(dayOffset: -2)], now: now, calendar: calendar), 0)
    }
    func testLocalDayBoundaryAndDistinctBudgets() {
        let id = UUID()
        let events = [activity(dayOffset: 0, state: .new), activity(dayOffset: -1, state: .new),
                      activity(dayOffset: 0, id: id), activity(dayOffset: 0, id: id),
                      activity(dayOffset: 0, state: .learning)]
        let budget = StudyStatistics.budget(events, now: now, newLimit: 10, reviewLimit: 100, calendar: calendar)
        XCTAssertEqual(budget.introducedToday, 1)
        XCTAssertEqual(budget.reviewedToday, 1)
        let midnight = calendar.startOfDay(for: now)
        let before = StudyActivity(cardID: UUID(), date: midnight.addingTimeInterval(-1), rating: .good, previousState: .new)
        XCTAssertEqual(StudyStatistics.budget([before], now: midnight, newLimit: 10, reviewLimit: 100, calendar: calendar).introducedToday, 0)
    }
    func testRetentionExcludesInitialLearning() {
        XCTAssertNil(StudyStatistics.retention([]))
        XCTAssertEqual(StudyStatistics.retention([activity(dayOffset: 0), activity(dayOffset: 0, rating: .again),
                                                  activity(dayOffset: 0, state: .learning)]), 0.5)
    }
}
