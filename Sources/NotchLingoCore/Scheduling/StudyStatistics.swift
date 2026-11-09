import Foundation

public struct StudyActivity: Sendable {
    public var cardID: UUID
    public var date: Date
    public var rating: Rating
    public var previousState: CardState
    public init(cardID: UUID, date: Date, rating: Rating, previousState: CardState) {
        self.cardID = cardID; self.date = date; self.rating = rating; self.previousState = previousState
    }
}

public enum StudyStatistics {
    /// Yesterday keeps a streak alive until the user studies today. Future events are ignored.
    public static func streak(_ activities: [StudyActivity], now: Date, calendar: Calendar = .current) -> Int {
        let days = Set(activities.filter { $0.date <= now }.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var count = 0
        while days.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    public static func budget(_ activities: [StudyActivity], now: Date, newLimit: Int, reviewLimit: Int,
                              calendar: Calendar = .current) -> DailyBudget {
        let today = activities.filter { $0.date <= now && calendar.isDate($0.date, inSameDayAs: now) }
        return DailyBudget(newLimit: newLimit, reviewLimit: reviewLimit,
            introducedToday: Set(today.filter { $0.previousState == .new }.map(\.cardID)).count,
            reviewedToday: Set(today.filter { $0.previousState == .review }.map(\.cardID)).count)
    }

    /// Recall success on scheduled review attempts; initial learning does not inflate retention.
    public static func retention(_ activities: [StudyActivity]) -> Double? {
        let reviews = activities.filter { $0.previousState == .review }
        guard !reviews.isEmpty else { return nil }
        return Double(reviews.filter { $0.rating != .again }.count) / Double(reviews.count)
    }
}
