import XCTest
@testable import NotchLingoCore

final class CSVCodecTests: XCTestCase {
    func testAllSeedsRoundTrip() throws {
        let decks = try SeedDecks.load()
        XCTAssertEqual(try CSVCodec.decode(CSVCodec.encode(decks)), decks)
    }
    func testQuotesCommasMultilineAndUnicodeRoundTrip() throws {
        var deck = try SeedDecks.load()[0]
        deck.name = "İngilizce, \"günlük\"\nSecond line"
        deck.cards[0].note = "Comma, quote \" and CRLF\r\nmore text"
        deck.cards[0].tags = ["a,b", "Türkçe"]
        XCTAssertEqual(try CSVCodec.decode(CSVCodec.encode([deck])), [deck])
    }
    func testMalformedCSVRejected() {
        for value in ["bad,header\n", "\"unclosed", "\"value\"garbage", "unexpected\"quote"] {
            XCTAssertThrowsError(try CSVCodec.decode(Data(value.utf8)))
        }
    }
    func testBOMSupported() throws {
        let decks = try SeedDecks.load()
        let data = Data([0xEF, 0xBB, 0xBF]) + (try CSVCodec.encode(decks))
        XCTAssertEqual(try CSVCodec.decode(data), decks)
    }
    func testDuplicateCardRejected() throws {
        let deck = try SeedDecks.load()[0]
        let csv = String(decoding: try CSVCodec.encode([deck]), as: UTF8.self)
        let lines = csv.components(separatedBy: "\r\n")
        XCTAssertThrowsError(try CSVCodec.decode(Data((csv + lines[1] + "\r\n").utf8)))
    }
}
