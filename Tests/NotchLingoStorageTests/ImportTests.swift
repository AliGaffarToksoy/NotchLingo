import XCTest
import SwiftData
@testable import NotchLingoCore
@testable import NotchLingoStorage

final class ImportTests: XCTestCase {
    @MainActor func testContentUpdatePreservesReviewProgress() throws {
        let store = try StudyStore(inMemory: true); try store.seedIfNeeded()
        var deck = try store.exportDecks()[0]
        let id = deck.cards[0].id
        let card = try XCTUnwrap(store.context.fetch(FetchDescriptor<StoredCard>()).first { $0.id == id })
        try store.record(.easy, for: card)
        deck.cards[0].definition = "A revised definition."
        try store.importDecks([deck])
        XCTAssertEqual(try card.content().definition, "A revised definition.")
        XCTAssertEqual(card.schedule.intervalDays, 4)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<ReviewEvent>()), 1)
    }
    @MainActor func testCrossDeckCollisionIsAtomic() throws {
        let store = try StudyStore(inMemory: true); try store.seedIfNeeded()
        var decks = try store.exportDecks()
        decks[1].cards[0].id = decks[0].cards[0].id
        XCTAssertThrowsError(try store.importDecks([decks[1]]))
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<StoredCard>()), 300)
    }
}
