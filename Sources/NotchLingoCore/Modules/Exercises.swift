import Foundation

public enum ExerciseKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case flashcard, meaning, cloze, natural, speaking, listening, builder
    public var id: String { rawValue }
    public var english: String {
        switch self {
        case .flashcard: return "Flashcard"
        case .meaning: return "Choose the meaning"
        case .cloze: return "Fill the gap"
        case .natural: return "Natural sentence"
        case .speaking: return "Speaking"
        case .listening: return "Listening"
        case .builder: return "Sentence builder"
        }
    }
    public var turkish: String {
        switch self {
        case .flashcard: return "Kelime kartı"
        case .meaning: return "Anlamı seç"
        case .cloze: return "Boşluğu doldur"
        case .natural: return "Doğal cümle"
        case .speaking: return "Konuşma"
        case .listening: return "Dinleme"
        case .builder: return "Cümle kur"
        }
    }
}

/// Every built-in exercise shares the plug-in contract; new modules need no scheduler changes.
public struct BuiltInModule: LearningModule {
    public let kind: ExerciseKind
    public var id: String { kind.rawValue }
    public var title: String { kind.english }
    public init(_ kind: ExerciseKind) { self.kind = kind }
    public func supports(_ card: CardContent) -> Bool { !card.examples.isEmpty }
    public func makePrompt(for card: CardContent) -> LearningPrompt {
        let sentence = card.examples[0].replacingOccurrences(of: "**", with: "")
        switch kind {
        case .flashcard: return LearningPrompt(cardID: card.id, instruction: card.term, answer: card.definition)
        case .meaning: return LearningPrompt(cardID: card.id, instruction: card.term, answer: card.definition)
        case .cloze:
            return LearningPrompt(cardID: card.id,
                instruction: sentence.replacingOccurrences(of: card.term, with: "______", options: .caseInsensitive), answer: card.term)
        case .natural: return LearningPrompt(cardID: card.id, instruction: card.term, answer: sentence)
        case .speaking, .listening, .builder:
            return LearningPrompt(cardID: card.id, instruction: sentence, answer: sentence)
        }
    }
}

public struct AnswerComparison: Equatable, Sendable {
    public let score: Double
    public let missedWords: [String]
    public let extraWords: [String]
}

/// Word edit-distance measures transcript similarity, never phonetic pronunciation accuracy.
public enum AnswerEvaluator {
    public static func words(_ text: String) -> [String] {
        text.lowercased().replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            .filter { !$0.isEmpty }
    }
    public static func compare(expected: String, actual: String) -> AnswerComparison {
        let a = words(expected), b = words(actual)
        var dp = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { dp[i][0] = i }
        for j in 0...b.count { dp[0][j] = j }
        if !a.isEmpty && !b.isEmpty {
            for i in 1...a.count {
                for j in 1...b.count {
                    dp[i][j] = min(dp[i-1][j] + 1, dp[i][j-1] + 1, dp[i-1][j-1] + (a[i-1] == b[j-1] ? 0 : 1))
                }
            }
        }
        var missing: [String] = [], extra: [String] = []
        var i = a.count, j = b.count
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && dp[i][j] == dp[i-1][j-1] + (a[i-1] == b[j-1] ? 0 : 1) {
                if a[i-1] != b[j-1] { missing.append(a[i-1]); extra.append(b[j-1]) }
                i -= 1; j -= 1
            } else if i > 0 && dp[i][j] == dp[i-1][j] + 1 { missing.append(a[i-1]); i -= 1 }
            else { extra.append(b[j-1]); j -= 1 }
        }
        let divisor = max(a.count, b.count, 1)
        return AnswerComparison(score: max(0, 1 - Double(dp[a.count][b.count]) / Double(divisor)),
                                missedWords: missing.reversed(), extraWords: extra.reversed())
    }
}
