import Foundation
import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import NotchLingoCore
import NotchLingoStorage

@MainActor final class AppModel: ObservableObject {
    let store: StudyStore
    let audio = AudioService()
    @Published var preferences = Preferences.load() { didSet { preferences.save(); preferencesChanged?() } }
    @Published var cards: [StoredCard] = []
    @Published var decks: [StoredDeck] = []
    @Published var events: [ReviewEvent] = []
    @Published var current: StoredCard?
    @Published var content: CardContent?
    @Published var kind: ExerciseKind = .flashcard
    @Published var prompt: LearningPrompt?
    @Published var options: [String] = []
    @Published var tokens: [String] = []
    @Published var selectedTokens: [Int] = []
    @Published var answer = ""
    @Published var revealed = false
    @Published var comparison: AnswerComparison?
    @Published var feedback = ""
    @Published var sessionActive = false
    @Published var sessionCount = 0
    @Published var secondsLeft = 0
    @Published var error: String?
    @Published var notice: String?
    @Published var showOnboarding = false
    @Published var panelExpanded = false
    @Published var pingVisible = false
    @Published var pingContent: CardContent?
    @Published var pingChoices: [String] = []
    @Published var pingAnswered = false
    @Published var pingCorrect = false
    var preferencesChanged: (() -> Void)?
    var expandPanel: ((Bool) -> Void)?
    var showDashboard: (() -> Void)?
    var showSettings: (() -> Void)?
    private var sessionEnd = Date()
    private var questionStart = Date()
    private var practice = false
    private var practiced = Set<UUID>()
    private var lastTick = Date()
    private var sessionTrackCounts: [Track: Int] = [:]

    init() throws {
        store = try StudyStore(); try store.seedIfNeeded(); try reload()
        showOnboarding = !preferences.onboarding
    }
    func t(_ en: String, _ tr: String) -> String { preferences.language == "tr" ? tr : en }
    func title(_ kind: ExerciseKind) -> String { t(kind.english, kind.turkish) }
    var activity: [StudyActivity] {
        events.compactMap { event in
            guard let rating = Rating(rawValue: event.ratingRaw), let state = CardState(rawValue: event.previousStateRaw) else { return nil }
            return StudyActivity(cardID: event.cardID, date: event.date, rating: rating, previousState: state)
        }
    }
    var todayEvents: [ReviewEvent] { events.filter { Calendar.current.isDateInToday($0.date) } }
    var streak: Int { StudyStatistics.streak(activity, now: Date()) }
    var budget: DailyBudget {
        StudyStatistics.budget(activity, now: Date(), newLimit: preferences.newLimit, reviewLimit: preferences.reviewLimit)
    }
    var wordOfDay: CardContent? {
        guard !cards.isEmpty else { return nil }
        let date = Calendar.current.startOfDay(for: Date())
        let index = abs(Int(date.timeIntervalSince1970 / 86400)) % cards.count
        return try? cards.sorted { $0.id.uuidString < $1.id.uuidString }[index].content()
    }
    func reload() throws {
        cards = try store.context.fetch(FetchDescriptor<StoredCard>(sortBy: [SortDescriptor(\StoredCard.term)]))
        decks = try store.context.fetch(FetchDescriptor<StoredDeck>())
        events = try store.context.fetch(FetchDescriptor<ReviewEvent>())
    }
    func queue(at date: Date = Date()) -> [StudyCandidate] {
        let lookup = Dictionary(uniqueKeysWithValues: decks.map { ($0.id, Track(rawValue: $0.trackRaw) ?? .everyday) })
        let candidates = cards.filter { !practice || ($0.schedule.isLeech && !practiced.contains($0.id)) }.map {
            StudyCandidate(id: $0.id, track: lookup[$0.deckID] ?? .everyday, schedule: $0.schedule)
        }
        if practice { return candidates }
        return SessionPlanner().queue(candidates, at: date, budget: budget, everydayWeight: preferences.everydayWeight)
    }
    func startSession(weakOnly: Bool = false) {
        practice = weakOnly; practiced = []; sessionTrackCounts = [:]
        sessionCount = 0; sessionActive = true; sessionEnd = Date().addingTimeInterval(Double(preferences.sessionMinutes * 60))
        secondsLeft = preferences.sessionMinutes * 60; pingVisible = false
        nextCard(); expandPanel?(true)
    }
    func nextCard() {
        audio.stopAll(); answer = ""; feedback = ""; revealed = false; comparison = nil; selectedTokens = []
        let available = queue()
        // Preserve the configured ratio across answers, even when the queue is recomputed.
        var candidate = available.first
        if let first = candidate, first.schedule.state == .new || first.schedule.state == .review {
            let target: Track = Double(sessionTrackCounts[.everyday, default: 0]) < Double(sessionCount + 1) * preferences.everydayWeight ? .everyday : .techWork
            candidate = available.first { $0.schedule.state == first.schedule.state && $0.track == target } ?? first
        }
        current = cards.first { $0.id == candidate?.id }
        content = try? current?.content()
        guard let content else { prompt = nil; return }
        let enabled = preferences.modules.compactMap(ExerciseKind.init(rawValue:))
        kind = enabled.isEmpty ? .flashcard : enabled[sessionCount % enabled.count]
        let module = BuiltInModule(kind)
        prompt = module.makePrompt(for: content)
        if kind == .meaning {
            let distractors = Array(Set(cards.filter { $0.id != content.id }.compactMap { try? $0.content().definition }))
                .filter { $0 != content.definition }.shuffled().prefix(3)
            options = ([content.definition] + distractors).shuffled()
        } else if kind == .natural, let answer = prompt?.answer {
            let words = answer.split(separator: " ").map(String.init)
            var variants = Set<String>()
            for _ in 0..<20 {
                let scrambled = words.shuffled().joined(separator: " ")
                if scrambled != answer { variants.insert(scrambled) }
                if variants.count == 3 { break }
            }
            options = ([answer] + variants.prefix(3)).shuffled()
        } else { options = [] }
        tokens = (prompt?.answer ?? "").split(separator: " ").map(String.init).shuffled()
        questionStart = Date()
    }
    func checkAnswer() {
        guard let prompt else { return }
        let actual: String
        if kind == .builder { actual = selectedTokens.map { tokens[$0] }.joined(separator: " ") }
        else if kind == .speaking { audio.finish(); actual = audio.transcript }
        else { actual = answer }
        comparison = AnswerEvaluator.compare(expected: prompt.answer, actual: actual)
        revealed = true
    }
    func rate(_ rating: Rating) {
        guard let current, revealed else { return }
        do {
            let track = decks.first { $0.id == current.deckID }.flatMap { Track(rawValue: $0.trackRaw) } ?? .everyday
            try store.record(rating, for: current, duration: min(300, Date().timeIntervalSince(questionStart)))
            practiced.insert(current.id); sessionTrackCounts[track, default: 0] += 1
            sessionCount += 1; try reload()
            if Date() >= sessionEnd { endSession() } else { nextCard() }
        } catch { self.error = error.localizedDescription }
    }
    func retry() { revealed = false; comparison = nil; answer = ""; selectedTokens = []; audio.stopAll(); audio.transcript = "" }
    func endSession() { sessionActive = false; current = nil; content = nil; audio.stopAll() }
    func tick() {
        let now = Date()
        if now.timeIntervalSince(lastTick) > 120 { endSession() } // do not resume a stale exercise after sleep
        lastTick = now
        if sessionActive {
            secondsLeft = max(0, Int(ceil(sessionEnd.timeIntervalSince(now))))
            if secondsLeft == 0 { endSession() }
            else if current == nil && !queue().isEmpty { nextCard() }
        }
    }
    func preparePing() {
        guard let candidate = queue().first, let stored = cards.first(where: { $0.id == candidate.id }),
              let card = try? stored.content() else { return }
        pingContent = card; pingAnswered = false; pingCorrect = false
        let others = Array(Set(cards.filter { $0.id != card.id }.compactMap { try? $0.content().definition }))
            .filter { $0 != card.definition }.shuffled().prefix(2)
        pingChoices = ([card.definition] + others).shuffled()
        pingVisible = true
    }
    func answerPing(_ value: String) {
        guard !pingAnswered, let card = pingContent, let stored = cards.first(where: { $0.id == card.id }) else { return }
        let correct = value == card.definition
        do {
            try store.record(correct ? .good : .again, for: stored, duration: 15)
            pingCorrect = correct; pingAnswered = true; try reload()
        } catch { error = error.localizedDescription }
    }
    func pause(minutes: Int = 60) { preferences.pauseUntil = Date().addingTimeInterval(Double(minutes * 60)); pingVisible = false }
    func importFile() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json, .commaSeparatedText]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count <= 10_000_000 else { throw DeckError.invalid("Maximum import size is 10 MB.") }
            let documents = try url.pathExtension.lowercased() == "csv" ? CSVCodec.decode(data) : [DeckCodec.decode(data)]
            try store.importDecks(documents); try reload()
            notice = t("Imported \(documents.reduce(0) { $0 + $1.cards.count }) cards. Progress preserved.", "\(documents.reduce(0) { $0 + $1.cards.count }) kart içe aktarıldı. İlerlemen korundu.")
        } catch { self.error = error.localizedDescription }
    }
    func exportFile(csv: Bool, deckID: UUID? = nil) {
        let panel = NSSavePanel(); panel.allowedContentTypes = csv ? [.commaSeparatedText] : [.json]
        panel.nameFieldStringValue = csv ? "NotchLingo-decks.csv" : "NotchLingo-deck.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let documents = try store.exportDecks().filter { deckID == nil || $0.id == deckID }
            let data: Data
            if csv { data = try CSVCodec.encode(documents) }
            else {
                guard let document = documents.first else { throw DeckError.invalid("No deck selected.") }
                data = try DeckCodec.encode(document)
            }
            try data.write(to: url, options: .atomic); notice = t("Deck exported.", "Deste dışa aktarıldı.")
        } catch { self.error = error.localizedDescription }
    }
}
