import XCTest
@testable import NotchLingoCore

final class DeckCodecTests: XCTestCase {
    func testSeedsHave150UniqueCompleteCardsPerTrack() throws {
        let decks = try SeedDecks.load()
        XCTAssertEqual(Set(decks.map(\.track)), Set(Track.allCases))
        XCTAssertEqual(decks.map { $0.cards.count }, [150, 150])
        XCTAssertEqual(Set(decks.flatMap(\.cards).map(\.id)).count, 300)
        for deck in decks { try DeckCodec.validate(deck) }
    }
    func testRoundTripPreservesUnicodeAndContent() throws {
        for deck in try SeedDecks.load() {
            XCTAssertEqual(try DeckCodec.decode(DeckCodec.encode(deck)), deck)
        }
    }
    func testDuplicateIDsRejected() throws {
        var deck = try SeedDecks.load()[0]
        deck.cards.append(deck.cards[0])
        XCTAssertThrowsError(try DeckCodec.encode(deck))
    }
    func testUnsupportedVersionRejected() throws {
        var deck = try SeedDecks.load()[0]; deck.schemaVersion = 2
        XCTAssertThrowsError(try DeckCodec.validate(deck))
    }
    func testMissingMeaningsAndBadExamplesRejected() throws {
        var deck = try SeedDecks.load()[0]; deck.cards[0].turkishMeaning = "  "
        XCTAssertThrowsError(try DeckCodec.validate(deck))
        deck = try SeedDecks.load()[0]; deck.cards[0].examples = ["No highlighted term.", "Also missing."]
        XCTAssertThrowsError(try DeckCodec.validate(deck))
        deck = try SeedDecks.load()[0]; deck.cards[0].examples[0] = "**wrong phrase**"
        XCTAssertThrowsError(try DeckCodec.validate(deck))
        deck = try SeedDecks.load()[0]; deck.cards[0].examples[0] += "**"
        XCTAssertThrowsError(try DeckCodec.validate(deck))
    }
    func testMalformedJSONAndInvalidEnumsRejected() throws {
        XCTAssertThrowsError(try DeckCodec.decode(Data("{".utf8)))
        let data = try DeckCodec.encode(SeedDecks.load()[0])
        let text = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"A2\"", with: "\"C2\"")
        XCTAssertThrowsError(try DeckCodec.decode(Data(text.utf8)))
    }
    func testOptionalNoteMayBeAbsent() throws {
        var deck = try SeedDecks.load()[0]; deck.cards[0].note = nil
        XCTAssertEqual(try DeckCodec.decode(DeckCodec.encode(deck)), deck)
    }
}
