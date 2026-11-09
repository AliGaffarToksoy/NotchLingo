import Foundation

public enum Rating: String, Codable, CaseIterable, Sendable { case again, hard, good, easy }
public enum CardState: String, Codable, Sendable { case new, learning, review, relearning }

/// Value state keeps scheduling deterministic and independent of SwiftData or the UI.
public struct ReviewSchedule: Codable, Equatable, Sendable {
    public var state: CardState = .new
    public var due: Date = .distantPast
    public var intervalDays: Double = 0
    public var ease: Double = 2.5
    public var learningStep: Int = 0
    public var repetitions: Int = 0
    public var lapses: Int = 0
    public var misses: Int = 0
    public var lastReviewed: Date?
    public var isLeech: Bool { misses >= 8 }
    public var isMature: Bool { state == .review && intervalDays >= 21 }
    public init() {}
}

/// SM-2-inspired four-button scheduler with explicit short learning/relearning steps.
/// Dates use elapsed time, not calendar days; daily limits use the user's local calendar.
public struct SRSEngine: Sendable {
    public init() {}

    public func rate(_ previous: ReviewSchedule, as rating: Rating, at now: Date) -> ReviewSchedule {
        var next = previous
        next.lastReviewed = now
        if rating == .again {
            next.misses += 1
            next.learningStep = 0
            if previous.state == .review {
                next.lapses += 1
                next.ease = max(1.3, previous.ease - 0.2)
                next.intervalDays = max(1, previous.intervalDays * 0.5)
                next.state = .relearning
            } else {
                next.state = previous.state == .relearning ? .relearning : .learning
            }
            next.due = now.addingTimeInterval(60)
            return next
        }
        if previous.state != .review {
            switch rating {
            case .hard:
                next.state = previous.state == .relearning ? .relearning : .learning
                next.due = now.addingTimeInterval(previous.learningStep == 0 ? 360 : 600)
            case .good:
                if previous.learningStep == 0 {
                    next.state = previous.state == .relearning ? .relearning : .learning
                    next.learningStep = 1
                    next.due = now.addingTimeInterval(600)
                } else {
                    graduate(&next, days: previous.state == .relearning ? max(1, previous.intervalDays) : 1, now: now)
                }
            case .easy:
                graduate(&next, days: previous.state == .relearning ? max(4, previous.intervalDays) : 4, now: now)
            case .again: break
            }
            return next
        }
        switch rating {
        case .hard:
            next.ease = max(1.3, previous.ease - 0.15)
            next.intervalDays = max(previous.intervalDays + 1, previous.intervalDays * 1.2)
        case .good:
            next.intervalDays = max(previous.intervalDays + 1, previous.intervalDays * previous.ease)
        case .easy:
            next.ease = min(3.5, previous.ease + 0.15)
            next.intervalDays = max(previous.intervalDays + 1, previous.intervalDays * next.ease * 1.3)
        case .again: break
        }
        next.intervalDays = min(36500, next.intervalDays.rounded())
        next.repetitions += 1
        next.due = now.addingTimeInterval(next.intervalDays * 86400)
        return next
    }

    private func graduate(_ schedule: inout ReviewSchedule, days: Double, now: Date) {
        schedule.state = .review
        schedule.learningStep = 0
        schedule.intervalDays = days
        schedule.repetitions += 1
        schedule.due = now.addingTimeInterval(days * 86400)
    }
}
