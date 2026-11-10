import Foundation
import NotchLingoCore

// Lightweight smoke checks for content contributors without Xcode/XCTest.
// These complement, and do not replace, the XCTest suites.
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw DeckError.invalid(message) }
}

let decks = try SeedDecks.load()
try require(decks.count == 2 && decks.allSatisfy { $0.cards.count >= 150 }, "Seed deck counts are incorrect.")
try require(Set(decks.flatMap(\.cards).map(\.id)).count == decks.flatMap(\.cards).count, "Cross-deck duplicate IDs.")
for deck in decks {
    try require(try DeckCodec.decode(DeckCodec.encode(deck)) == deck, "JSON round trip failed.")
}
var invalid = decks[0]
invalid.cards.append(invalid.cards[0])
var rejected = false
do { try DeckCodec.validate(invalid) } catch { rejected = true }
try require(rejected, "Duplicate IDs should be rejected.")

let now = Date(timeIntervalSince1970: 1_700_000_000)
let engine = SRSEngine()
let failed = engine.rate(ReviewSchedule(), as: .again, at: now)
try require(failed.due.timeIntervalSince(now) == 60, "Again must return after one minute.")
let learning = engine.rate(failed, as: .good, at: failed.due)
try require(learning.due.timeIntervalSince(failed.due) == 600, "Good must use the ten-minute step.")
let graduated = engine.rate(learning, as: .good, at: learning.due)
try require(graduated.state == .review && graduated.intervalDays == 1, "Learning must graduate to one day.")
let easy = engine.rate(ReviewSchedule(), as: .easy, at: now)
try require(easy.state == .review && easy.intervalDays == 4, "Easy must graduate to four days.")
let lapse = engine.rate(easy, as: .again, at: easy.due)
try require(lapse.state == .relearning && lapse.lapses == 1, "A review lapse must enter relearning.")
var leech = ReviewSchedule()
for _ in 0..<8 { leech = engine.rate(leech, as: .again, at: now) }
try require(leech.isLeech, "Repeated failures must flag a leech.")
let candidates = decks.flatMap { deck in
    deck.cards.map { StudyCandidate(id: $0.id, track: deck.track, schedule: ReviewSchedule()) }
}
let queue = SessionPlanner().queue(candidates, at: now, budget: DailyBudget(), everydayWeight: 0.7)
try require(queue.count == 10 && queue.filter { $0.track == .everyday }.count == 7, "70/30 balance failed.")
let step = StudyCandidate(id: UUID(), track: .everyday, schedule: failed)
let shortQueue = SessionPlanner().queue(candidates + [step], at: failed.due,
                                        budget: DailyBudget(newLimit: 0, reviewLimit: 0))
try require(shortQueue.map(\.id) == [step.id], "Learning steps must bypass exhausted daily budgets.")
print("PASS: \(decks.flatMap(\.cards).count) cards, JSON round trips, duplicate rejection, SRS smoke checks, track balance, and learning budget bypass.")
print("Full app, SwiftData, and XCTest verification still require full Xcode.")

let csv = try CSVCodec.encode(decks)
try require(try CSVCodec.decode(csv) == decks, "CSV round trip failed.")
let spoken = AnswerEvaluator.compare(expected: "Could you review my pull request?", actual: "could you review my request")
try require(spoken.missedWords == ["pull"] && spoken.score > 0.8, "Transcript alignment failed.")
try require(AnswerEvaluator.compare(expected: "Hello!", actual: "hello").score == 1, "Case/punctuation matching failed.")
print("PASS: CSV round trip and transcript alignment.")
