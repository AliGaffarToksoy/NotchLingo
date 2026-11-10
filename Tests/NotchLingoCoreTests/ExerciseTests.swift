import XCTest
@testable import NotchLingoCore

final class ExerciseTests: XCTestCase {
    func testAllModulesCreatePromptsForSeeds() throws {
        for card in try SeedDecks.load().flatMap(\.cards) {
            for kind in ExerciseKind.allCases {
                let module = BuiltInModule(kind)
                XCTAssertTrue(module.supports(card))
                let prompt = module.makePrompt(for: card)
                XCTAssertEqual(prompt.cardID, card.id)
                XCTAssertFalse(prompt.answer.isEmpty)
                XCTAssertFalse(prompt.instruction.contains("**"))
            }
        }
    }
    func testClozeMasksTarget() throws {
        let card = try SeedDecks.load()[0].cards[0]
        let prompt = BuiltInModule(.cloze).makePrompt(for: card)
        XCTAssertTrue(prompt.instruction.contains("______"))
        XCTAssertFalse(prompt.instruction.localizedCaseInsensitiveContains(card.term))
    }
    func testTranscriptAlignmentHandlesMissingAndExtraWords() {
        let result = AnswerEvaluator.compare(expected: "Please review my pull request", actual: "please review my request today")
        XCTAssertEqual(result.missedWords, ["pull"])
        XCTAssertEqual(result.extraWords, ["today"])
        XCTAssertLessThan(result.score, 1)
    }
    func testRepeatedWordsAndPunctuation() {
        XCTAssertEqual(AnswerEvaluator.compare(expected: "Very very good!", actual: "very good").missedWords, ["very"])
        XCTAssertEqual(AnswerEvaluator.compare(expected: "I'm ready.", actual: "I’m ready!").score, 1)
        XCTAssertEqual(AnswerEvaluator.compare(expected: "hello", actual: "").score, 0)
        XCTAssertEqual(AnswerEvaluator.compare(expected: "", actual: "unexpected").score, 0)
    }
}
