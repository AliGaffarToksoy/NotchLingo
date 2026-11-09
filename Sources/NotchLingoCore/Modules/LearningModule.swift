import Foundation

/// UI-independent extension point. Concrete exercise modules arrive in phases 2–4.
public protocol LearningModule {
    var id: String { get }
    var title: String { get }
    func supports(_ card: CardContent) -> Bool
    func makePrompt(for card: CardContent) -> LearningPrompt
}

public struct LearningPrompt: Equatable, Sendable {
    public let cardID: UUID
    public let instruction: String
    public let answer: String
    public init(cardID: UUID, instruction: String, answer: String) {
        self.cardID = cardID; self.instruction = instruction; self.answer = answer
    }
}
