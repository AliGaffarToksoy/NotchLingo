import Foundation
import SwiftData
import NotchLingoCore

extension StudyStore {
    /// Validates the whole batch before any mutation. Existing IDs update content only.
    public func importDecks(_ documents: [DeckDocument]) throws {
        var owners: [UUID: UUID] = [:]
        for document in documents {
            try DeckCodec.validate(document)
            for card in document.cards {
                guard owners.updateValue(document.id, forKey: card.id) == nil else {
                    throw DeckError.invalid("Repeated card ID across imported decks.")
                }
            }
        }
        guard Set(documents.map(\.id)).count == documents.count else { throw DeckError.invalid("Duplicate deck IDs.") }
        let oldDecks = try context.fetch(FetchDescriptor<StoredDeck>())
        let oldCards = try context.fetch(FetchDescriptor<StoredCard>())
        for card in oldCards {
            if let owner = owners[card.id], owner != card.deckID { throw DeckError.invalid("A card ID already belongs to another deck.") }
        }
        do {
            for document in documents {
                if let existing = oldDecks.first(where: { $0.id == document.id }) {
                    existing.name = document.name; existing.trackRaw = document.track.rawValue
                } else { context.insert(StoredDeck(document: document)) }
                for content in document.cards {
                    if let existing = oldCards.first(where: { $0.id == content.id }) {
                        existing.term = content.term; existing.contentData = try JSONEncoder().encode(content)
                    } else { context.insert(try StoredCard(content: content, deckID: document.id)) }
                }
            }
            try context.save()
        } catch { context.rollback(); throw error }
    }
    public func exportDecks() throws -> [DeckDocument] {
        let decks = try context.fetch(FetchDescriptor<StoredDeck>())
        let cards = try context.fetch(FetchDescriptor<StoredCard>())
        return try decks.map { deck in
            let content = try cards.filter { $0.deckID == deck.id }.sorted { $0.term < $1.term }.map { try $0.content() }
            // Round-trip through the public document codec keeps format validation centralized.
            let payload: [String: Any] = ["schemaVersion": 1, "id": deck.id.uuidString, "name": deck.name,
                "track": deck.trackRaw, "cards": try JSONSerialization.jsonObject(with: JSONEncoder().encode(content))]
            return try DeckCodec.decode(JSONSerialization.data(withJSONObject: payload))
        }
    }
}
