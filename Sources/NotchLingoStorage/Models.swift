import NotchLingoCore
import Foundation
import SwiftData

@Model public final class StoredDeck {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var trackRaw: String
    public var schemaVersion: Int
    public init(document: DeckDocument) {
        id = document.id; name = document.name; trackRaw = document.track.rawValue
        schemaVersion = document.schemaVersion
    }
}

/// Content is an encoded, validated value; scheduling columns remain queryable.
@Model public final class StoredCard {
    @Attribute(.unique) public var id: UUID
    public var deckID: UUID
    public var term: String
    public var contentData: Data
    public var stateRaw: String
    public var due: Date
    public var intervalDays: Double
    public var ease: Double
    public var learningStep: Int
    public var repetitions: Int
    public var lapses: Int
    public var misses: Int
    public var lastReviewed: Date?
    public var introducedAt: Date?

    public init(content: CardContent, deckID: UUID) throws {
        id = content.id; self.deckID = deckID; term = content.term
        contentData = try JSONEncoder().encode(content)
        stateRaw = CardState.new.rawValue; due = .distantPast
        intervalDays = 0; ease = 2.5; learningStep = 0; repetitions = 0; lapses = 0; misses = 0
    }
    public func content() throws -> CardContent { try JSONDecoder().decode(CardContent.self, from: contentData) }
    public var schedule: ReviewSchedule {
        get {
            var value = ReviewSchedule()
            value.state = CardState(rawValue: stateRaw) ?? .new
            value.due = due; value.intervalDays = intervalDays; value.ease = ease
            value.learningStep = learningStep; value.repetitions = repetitions
            value.lapses = lapses; value.misses = misses; value.lastReviewed = lastReviewed
            return value
        }
        set {
            stateRaw = newValue.state.rawValue; due = newValue.due; intervalDays = newValue.intervalDays
            ease = newValue.ease; learningStep = newValue.learningStep; repetitions = newValue.repetitions
            lapses = newValue.lapses; misses = newValue.misses; lastReviewed = newValue.lastReviewed
        }
    }
}

/// Immutable review events support retention, streaks, daily limits, and future charts.
@Model public final class ReviewEvent {
    @Attribute(.unique) public var id: UUID
    public var cardID: UUID
    public var date: Date
    public var ratingRaw: String
    public var previousStateRaw: String
    public var durationSeconds: Double
    public init(cardID: UUID, date: Date, rating: Rating, previousState: CardState, durationSeconds: Double) {
        id = UUID(); self.cardID = cardID; self.date = date; ratingRaw = rating.rawValue
        previousStateRaw = previousState.rawValue
        self.durationSeconds = durationSeconds.isFinite ? max(0, durationSeconds) : 0
    }
}

@Model public final class StudyPreferences {
    @Attribute(.unique) public var id: String
    public var newCardsPerDay: Int
    public var maxReviewsPerDay: Int
    public var everydayWeight: Double
    public var showTurkishHints: Bool
    public var voiceLocale: String
    public var activeStartHour: Int
    public var activeEndHour: Int
    public var pingIntervalMinutes: Int
    public var sessionMinutes: Int
    public var enabledModuleIDs: [String]
    public var pausedUntil: Date?
    public init() {
        id = "local"; newCardsPerDay = 10; maxReviewsPerDay = 100; everydayWeight = 0.5
        showTurkishHints = true; voiceLocale = "en-US"; activeStartHour = 9; activeEndHour = 21
        pingIntervalMinutes = 60; sessionMinutes = 3; enabledModuleIDs = ["flashcard"]
    }
}
