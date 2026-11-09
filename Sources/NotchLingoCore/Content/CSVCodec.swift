import Foundation

/// RFC 4180 CSV with UTF-8 text and JSON-encoded tag arrays. No spreadsheet formulas are evaluated.
public enum CSVCodec {
    public static let header = ["schemaVersion", "deckID", "deckName", "track", "id", "term", "partOfSpeech",
                                "cefr", "definition", "turkishMeaning", "example1", "example2", "example3", "ipaUS", "ipaUK", "note", "tags"]
    public static func encode(_ decks: [DeckDocument]) throws -> Data {
        var rows = [header]
        for deck in decks {
            try DeckCodec.validate(deck)
            for card in deck.cards {
                rows.append([String(deck.schemaVersion), deck.id.uuidString, deck.name, deck.track.rawValue,
                             card.id.uuidString, card.term, card.partOfSpeech, card.cefr.rawValue, card.definition,
                             card.turkishMeaning, card.examples[0], card.examples[1], card.examples.count > 2 ? card.examples[2] : "",
                             card.ipaUS, card.ipaUK, card.note ?? "", String(decoding: try JSONEncoder().encode(card.tags), as: UTF8.self)])
            }
        }
        return Data(rows.map { $0.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",") }
            .joined(separator: "\r\n").appending("\r\n").utf8)
    }
    public static func decode(_ data: Data) throws -> [DeckDocument] {
        guard var text = String(data: data, encoding: .utf8) else { throw DeckError.invalid("CSV must be UTF-8.") }
        if text.first == "\u{FEFF}" { text.removeFirst() }
        let rows = try parse(text)
        guard rows.first == header else { throw DeckError.invalid("CSV header must match the NotchLingo CSV template.") }
        var documents: [UUID: DeckDocument] = [:]
        var order: [UUID] = []
        for row in rows.dropFirst() {
            guard row.count == header.count, let version = Int(row[0]), let deckID = UUID(uuidString: row[1]),
                  let track = Track(rawValue: row[3]), let id = UUID(uuidString: row[4]), let cefr = CEFRLevel(rawValue: row[7]) else {
                throw DeckError.invalid("Invalid CSV row or identifier.")
            }
            if let existing = documents[deckID] {
                guard existing.name == row[2], existing.track == track, existing.schemaVersion == version else {
                    throw DeckError.invalid("Conflicting deck metadata in CSV.")
                }
            } else {
                documents[deckID] = DeckDocument(schemaVersion: version, id: deckID, name: row[2], track: track, cards: [])
                order.append(deckID)
            }
            let tags = try JSONDecoder().decode([String].self, from: Data(row[16].utf8))
            let card = CardContent(id: id, term: row[5], partOfSpeech: row[6], cefr: cefr, definition: row[8],
                                  turkishMeaning: row[9], examples: [row[10], row[11]] + (row[12].isEmpty ? [] : [row[12]]),
                                  ipaUS: row[13], ipaUK: row[14], note: row[15].isEmpty ? nil : row[15], tags: tags)
            documents[deckID]?.cards.append(card)
        }
        let result = order.compactMap { documents[$0] }
        guard !result.isEmpty else { throw DeckError.invalid("CSV contains no cards.") }
        for deck in result { try DeckCodec.validate(deck) }
        return result
    }
    private static func parse(_ text: String) throws -> [[String]] {
        // Iterate Unicode scalars so CRLF is two delimiters rather than one grapheme.
        let chars = Array(text.unicodeScalars)
        var rows: [[String]] = [], row: [String] = [], field = ""
        var quoted = false, closed = false, i = 0
        func finishField() { row.append(field); field = ""; closed = false }
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i+1] == "\"" { field.append("\""); i += 1 }
                    else { quoted = false; closed = true }
                } else { field.unicodeScalars.append(c) }
            } else if c == "," { finishField() }
            else if c == "\n" || c == "\r" {
                finishField(); rows.append(row); row = []
                if c == "\r" && i+1 < chars.count && chars[i+1] == "\n" { i += 1 }
            } else if c == "\"" {
                guard field.isEmpty && !closed else { throw DeckError.invalid("Unexpected quote in CSV.") }
                quoted = true
            } else {
                guard !closed else { throw DeckError.invalid("Text after closing CSV quote.") }
                field.unicodeScalars.append(c)
            }
            i += 1
        }
        guard !quoted else { throw DeckError.invalid("Unclosed CSV quote.") }
        if !field.isEmpty || !row.isEmpty || closed { finishField(); rows.append(row) }
        return rows
    }
}
