import NotchLingoCore
import Foundation
import SwiftData

/// All persistence mutations run on the main actor and save atomically.
@MainActor public final class StudyStore {
    public let container: ModelContainer
    public var context: ModelContext { container.mainContext }

    public init(inMemory: Bool = false, storeURL: URL? = nil) throws {
        let schema = Schema([StoredDeck.self, StoredCard.self, ReviewEvent.self, StudyPreferences.self])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            let url: URL
            if let storeURL { url = storeURL }
            else {
                let directory = try FileManager.default.url(for: .applicationSupportDirectory,
                    in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("NotchLingo", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                url = directory.appendingPathComponent("NotchLingo.store")
            }
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        }
        container = try ModelContainer(for: schema, configurations: [configuration])
        context.autosaveEnabled = false
    }

    /// Idempotent seeding adds missing cards without changing progress or existing content.
    public func seedIfNeeded() throws {
        let documents = try SeedDecks.load()
        let existingDecks = try context.fetch(FetchDescriptor<StoredDeck>())
        let existingCards = try context.fetch(FetchDescriptor<StoredCard>())
        var deckIDs = Set(existingDecks.map(\.id))
        var cardIDs = Set(existingCards.map(\.id))
        do {
            for document in documents {
                if deckIDs.insert(document.id).inserted { context.insert(StoredDeck(document: document)) }
                for content in document.cards where cardIDs.insert(content.id).inserted {
                    context.insert(try StoredCard(content: content, deckID: document.id))
                }
            }
            if try context.fetchCount(FetchDescriptor<StudyPreferences>()) == 0 { context.insert(StudyPreferences()) }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    public func record(_ rating: Rating, for card: StoredCard, at now: Date = Date(), duration: Double = 0) throws {
        let previous = card.schedule
        do {
            if previous.state == .new { card.introducedAt = now }
            card.schedule = SRSEngine().rate(previous, as: rating, at: now)
            context.insert(ReviewEvent(cardID: card.id, date: now, rating: rating,
                                       previousState: previous.state, durationSeconds: duration))
            try context.save()
        } catch { context.rollback(); throw error }
    }
}
