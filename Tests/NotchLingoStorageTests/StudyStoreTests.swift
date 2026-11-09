import NotchLingoStorage
import XCTest
import SwiftData
@testable import NotchLingoCore

final class StudyStoreTests: XCTestCase {
    @MainActor func testSeedIsIdempotentAndPreservesProgress() throws {
        let store = try StudyStore(inMemory: true)
        try store.seedIfNeeded()
        let card = try XCTUnwrap(store.context.fetch(FetchDescriptor<StoredCard>()).first)
        try store.record(.again, for: card, at: Date(timeIntervalSince1970: 12345))
        try store.seedIfNeeded()
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<StoredDeck>()), 2)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<StoredCard>()), 60)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<StudyPreferences>()), 1)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<ReviewEvent>()), 1)
        XCTAssertEqual(card.schedule.state, .learning)
        XCTAssertEqual(card.schedule.misses, 1)
        XCTAssertEqual(try card.content().id, card.id)
    }

    @MainActor func testDiskStoreCanReopenWithReviewHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let id: UUID
        do {
            let store = try StudyStore(storeURL: url)
            try store.seedIfNeeded()
            let card = try XCTUnwrap(store.context.fetch(FetchDescriptor<StoredCard>()).first)
            id = card.id
            try store.record(.easy, for: card, duration: 12)
        }
        let reopened = try StudyStore(storeURL: url)
        let card = try XCTUnwrap(reopened.context.fetch(FetchDescriptor<StoredCard>()).first { $0.id == id })
        XCTAssertEqual(card.schedule.intervalDays, 4)
        XCTAssertNotNil(card.introducedAt)
        XCTAssertEqual(try reopened.context.fetch(FetchDescriptor<ReviewEvent>()).first?.durationSeconds, 12)
    }
}
