import Foundation

public struct StudyCandidate: Identifiable, Sendable {
    public var id: UUID
    public var track: Track
    public var schedule: ReviewSchedule
    public init(id: UUID, track: Track, schedule: ReviewSchedule) {
        self.id = id; self.track = track; self.schedule = schedule
    }
}

public struct DailyBudget: Sendable {
    public var newLimit: Int
    public var reviewLimit: Int
    public var introducedToday: Int
    /// Distinct review cards studied today; repeated learning attempts do not use this budget.
    public var reviewedToday: Int
    public init(newLimit: Int = 10, reviewLimit: Int = 100, introducedToday: Int = 0, reviewedToday: Int = 0) {
        self.newLimit = newLimit; self.reviewLimit = reviewLimit
        self.introducedToday = introducedToday; self.reviewedToday = reviewedToday
    }
}

/// Short steps bypass the daily cap; due reviews precede new cards. Recompute after every answer.
public struct SessionPlanner: Sendable {
    public init() {}
    public func queue(_ candidates: [StudyCandidate], at now: Date, budget: DailyBudget,
                      everydayWeight: Double = 0.5) -> [StudyCandidate] {
        let weight = everydayWeight.isFinite ? min(1, max(0, everydayWeight)) : 0.5
        let due = candidates.filter { $0.schedule.due <= now }
        let steps = due.filter { $0.schedule.state == .learning || $0.schedule.state == .relearning }
            .sorted(by: dueOrder)
        let reviews = balance(due.filter { $0.schedule.state == .review }, weight: weight)
            .prefix(max(0, budget.reviewLimit - budget.reviewedToday))
        let fresh = balance(candidates.filter { $0.schedule.state == .new }, weight: weight)
            .prefix(max(0, budget.newLimit - budget.introducedToday))
        return steps + reviews + fresh
    }

    private func dueOrder(_ lhs: StudyCandidate, _ rhs: StudyCandidate) -> Bool {
        lhs.schedule.due == rhs.schedule.due ? lhs.id.uuidString < rhs.id.uuidString : lhs.schedule.due < rhs.schedule.due
    }

    private func balance(_ items: [StudyCandidate], weight: Double) -> [StudyCandidate] {
        var daily = items.filter { $0.track == .everyday }.sorted(by: dueOrder)
        var tech = items.filter { $0.track == .techWork }.sorted(by: dueOrder)
        // A zero weight disables that track, but never suppresses already-active short steps.
        if weight == 0 { return tech }
        if weight == 1 { return daily }
        var result: [StudyCandidate] = []
        var dailyCount = 0
        while !daily.isEmpty || !tech.isEmpty {
            let chooseDaily = tech.isEmpty || (!daily.isEmpty && Double(dailyCount) < Double(result.count + 1) * weight)
            if chooseDaily { result.append(daily.removeFirst()); dailyCount += 1 }
            else { result.append(tech.removeFirst()) }
        }
        return result
    }
}
