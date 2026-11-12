import Foundation

public enum DeckError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

/// Shared validation for bundled resources and future user imports/exports.
public enum DeckCodec {
    public static func decode(_ data: Data) throws -> DeckDocument {
        let deck = try JSONDecoder().decode(DeckDocument.self, from: data)
        try validate(deck)
        return deck
    }

    public static func encode(_ deck: DeckDocument) throws -> Data {
        try validate(deck)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(deck)
    }

    public static func validate(_ deck: DeckDocument) throws {
        guard deck.schemaVersion == 1 else { throw DeckError.invalid("Unsupported deck schema version.") }
        guard !deck.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !deck.cards.isEmpty else { throw DeckError.invalid("A deck needs a name and at least one card.") }
        guard Set(deck.cards.map(\.id)).count == deck.cards.count else {
            throw DeckError.invalid("Card IDs must be unique within a deck.")
        }
        for card in deck.cards {
            let required = [card.term, card.partOfSpeech, card.definition, card.turkishMeaning,
                            card.ipaUS, card.ipaUK] + card.tags
            guard required.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                  !card.tags.isEmpty, Set(card.tags).count == card.tags.count,
                  (2...3).contains(card.examples.count) else {
                throw DeckError.invalid("Card \(card.id) has missing fields, invalid tags, or needs 2–3 examples.")
            }
            // English learning content must not inherit Turkish I/ı casing rules
            // (or any other device locale) during startup and import validation.
            for example in card.examples {
                let segments = example.components(separatedBy: "**")
                guard segments.count >= 3, segments.count % 2 == 1,
                      stride(from: 1, to: segments.count, by: 2).allSatisfy({
                          segments[$0].trimmingCharacters(in: .whitespacesAndNewlines)
                              .compare(card.term, options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX")) == .orderedSame
                      }) else {
                    throw DeckError.invalid("Each example for '\(card.term)' must highlight **\(card.term)**.")
                }
            }
        }
    }
}

public enum SeedDecks {
    public static func load() throws -> [DeckDocument] {
        try ["everyday", "tech-work"].map { name in
            let packaged = Bundle.main.resourceURL?.appendingPathComponent("NotchLingo_NotchLingoCore.bundle")
            let resourceBundle = packaged.flatMap(Bundle.init(url:)) ?? Bundle.module
            guard let url = resourceBundle.url(forResource: name, withExtension: "json", subdirectory: "Decks") else {
                throw DeckError.invalid("Missing bundled deck: \(name)")
            }
            return try DeckCodec.decode(Data(contentsOf: url))
        }
    }
}
