import Foundation

public enum Track: String, Codable, CaseIterable, Sendable {
    case everyday, techWork
}

public enum CEFRLevel: String, Codable, CaseIterable, Sendable {
    case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1"
}

/// Portable content only. Progress is local and never overwritten by deck imports.
public struct DeckDocument: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var id: UUID
    public var name: String
    public var track: Track
    public var cards: [CardContent]
}

/// Use **target phrase** in examples to identify the text the UI should highlight.
public struct CardContent: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var term: String
    public var partOfSpeech: String
    public var cefr: CEFRLevel
    public var definition: String
    public var turkishMeaning: String
    public var examples: [String]
    public var ipaUS: String
    public var ipaUK: String
    public var note: String?
    public var tags: [String]
}
