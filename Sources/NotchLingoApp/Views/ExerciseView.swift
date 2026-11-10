import SwiftUI
import NotchLingoCore

struct ExerciseView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var audio: AudioService
    @FocusState private var typing: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(model.title(model.kind), systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(.teal)
                Spacer()
                Text("\(model.sessionCount) · \(model.secondsLeft / 60):\(String(format: "%02d", model.secondsLeft % 60))")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Button { model.endSession() } label: { Image(systemName: "stop.circle") }
                    .buttonStyle(.plain).help(model.t("End session", "Oturumu bitir"))
            }
            if let card = model.content, let prompt = model.prompt {
                HStack {
                    Text(card.cefr.rawValue).font(.system(size: 10, weight: .medium)).padding(.horizontal, 6).padding(.vertical, 3).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                    Text(card.partOfSpeech).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if model.kind != .listening && model.kind != .cloze {
                        Button { audio.speak(model.kind == .speaking ? prompt.answer : card.term, locale: model.preferences.voice) }
                        label: { Image(systemName: "speaker.wave.2.fill") }.buttonStyle(.plain)
                            .accessibilityLabel(model.t("Hear pronunciation", "Telaffuzu dinle"))
                    }
                }
                Group {
                    switch model.kind {
                    case .flashcard:
                        Text(card.term).font(.system(size: 25, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                        if !model.revealed {
                            Button(model.t("Reveal meaning", "Anlamı göster")) { model.revealed = true }
                                .buttonStyle(.borderedProminent).tint(LingoStyle.accent).keyboardShortcut(.space, modifiers: [])
                        }
                    case .meaning, .natural:
                        Text(model.kind == .meaning ? card.term : model.t("Which sentence is natural?", "Hangi cümle doğal?"))
                            .font(.title3.bold())
                        ForEach(model.options, id: \.self) { option in
                            Button { model.answer = option; model.checkAnswer() } label: {
                                HStack { Text(option).multilineTextAlignment(.leading); Spacer()
                                    if model.revealed && option == prompt.answer { Image(systemName: "checkmark.circle.fill").foregroundStyle(.teal) }
                                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(model.answer == option ? Color.teal.opacity(0.16) : .white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain).disabled(model.revealed)
                        }
                    case .cloze:
                        Text(prompt.instruction).font(.title3.weight(.medium))
                        if model.preferences.hints { Text(card.turkishMeaning).font(.callout).foregroundStyle(.secondary) }
                        answerField
                    case .listening:
                        Text(model.t("Listen, then type what you hear.", "Dinle ve duyduğunu yaz.")).font(.title3.bold())
                        Button { audio.speak(prompt.answer, locale: model.preferences.voice) } label: {
                            Label(model.t("Play sentence", "Cümleyi dinle"), systemImage: "waveform")
                        }.buttonStyle(.borderedProminent).tint(LingoStyle.accent)
                        answerField
                    case .builder:
                        Text(model.t("Build the sentence", "Cümleyi oluştur")).font(.title3.bold())
                        Text(model.selectedTokens.map { model.tokens[$0] }.joined(separator: " "))
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(10)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                            ForEach(model.tokens.indices, id: \.self) { index in
                                Button(model.tokens[index]) { model.selectedTokens.append(index) }
                                    .buttonStyle(.bordered).disabled(model.selectedTokens.contains(index) || model.revealed)
                            }
                        }
                        HStack {
                            Button(model.t("Undo", "Geri al")) { if !model.selectedTokens.isEmpty { model.selectedTokens.removeLast() } }
                                .disabled(model.selectedTokens.isEmpty || model.revealed)
                            Button(model.t("Check", "Kontrol et")) { model.checkAnswer() }
                                .disabled(model.selectedTokens.count != model.tokens.count || model.revealed)
                        }
                    case .speaking:
                        Text(model.t("Say this aloud", "Sesli söyle")).font(.caption).foregroundStyle(.secondary)
                        Text(prompt.instruction).font(.title3.bold())
                        HStack {
                            Button {
                                if audio.recording { audio.finish() } else { Task { await audio.begin(locale: model.preferences.voice) } }
                            } label: {
                                Label(audio.recording ? model.t("Stop recording", "Kaydı durdur") : model.t("Start speaking", "Konuşmaya başla"),
                                      systemImage: audio.recording ? "stop.fill" : "mic.fill")
                            }.buttonStyle(.borderedProminent).tint(audio.recording ? .red : .mint).disabled(model.revealed)
                            Button(model.t("Check", "Kontrol et")) { model.checkAnswer() }
                                .disabled(audio.transcript.isEmpty || audio.recording || model.revealed)
                        }
                        Text(audio.transcript.isEmpty ? model.t("Your words appear here. Audio is not saved.", "Söylediklerin burada görünür. Ses kaydedilmez.") : audio.transcript)
                            .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
                if let error = audio.error { Text(error).font(.caption).foregroundStyle(.orange) }
                if model.revealed { revealedContent(card) }
            }
        }.onChange(of: model.current?.id) { typing = false }
    }
    private var answerField: some View {
        HStack {
            TextField(model.t("Your answer", "Yanıtın"), text: $model.answer)
                .textFieldStyle(.roundedBorder).focused($typing).onSubmit { if !model.answer.isEmpty { model.checkAnswer() } }
                .disabled(model.revealed)
            Button(model.t("Check", "Kontrol et")) { model.checkAnswer() }.disabled(model.answer.isEmpty || model.revealed)
        }
    }
    private func revealedContent(_ card: CardContent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let comparison = model.comparison {
                HStack {
                    Image(systemName: comparison.score >= 0.85 ? "checkmark.circle.fill" : "arrow.clockwise.circle.fill")
                    Text(model.t("Match: ", "Eşleşme: ") + "\(Int(comparison.score * 100))%")
                    Spacer()
                    Button(model.t("Retry", "Tekrar dene")) { model.retry() }
                }.foregroundStyle(comparison.score >= 0.85 ? .mint : .orange)
                if !comparison.missedWords.isEmpty {
                    Text(model.t("Missing / different: ", "Eksik / farklı: ") + comparison.missedWords.joined(separator: ", "))
                        .font(.caption).foregroundStyle(.orange)
                }
                if model.kind == .speaking { Text(model.t("Transcript similarity, not a pronunciation diagnosis.", "Metin benzerliğidir; telaffuz teşhisi değildir.")).font(.caption2).foregroundStyle(.secondary) }
                Text(model.prompt?.answer ?? "").font(.callout.weight(.semibold))
            }
            Divider()
            Text(card.definition).font(.system(size: 15, weight: .medium)).fixedSize(horizontal: false, vertical: true)
            Text(card.turkishMeaning).font(.system(size: 14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(model.preferences.voice == "en-GB" ? card.ipaUK : card.ipaUS).font(.caption).foregroundStyle(.secondary)
                Button { audio.speak(card.term, locale: model.preferences.voice) } label: { Image(systemName: "speaker.wave.2") }.buttonStyle(.plain)
            }
            if let example = card.examples.first {
                Text((try? AttributedString(markdown: example)) ?? AttributedString(example))
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 12).overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 1).fill(.teal.opacity(0.6)).frame(width: 2) }
            }
            DisclosureGroup(model.t("More examples & notes", "Diğer örnekler ve notlar")) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(card.examples.dropFirst()), id: \.self) { example in
                        Text((try? AttributedString(markdown: example)) ?? AttributedString(example)).fixedSize(horizontal: false, vertical: true)
                    }
                    if model.preferences.hints, let note = card.note { Text(note).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                }.font(.caption).padding(.top, 8).frame(maxWidth: .infinity, alignment: .leading)
            }.font(.caption).foregroundStyle(.secondary)
            Divider().padding(.top, 4)
            HStack(spacing: 8) {
                ratingButton(.again, en: "Again", tr: "Tekrar", color: .red, key: "1")
                ratingButton(.hard, en: "Hard", tr: "Zor", color: .orange, key: "2")
                ratingButton(.good, en: "Good", tr: "İyi", color: .teal, key: "3")
                ratingButton(.easy, en: "Easy", tr: "Kolay", color: .cyan, key: "4")
            }.padding(.top, 6)
        }
    }
    private func ratingButton(_ rating: Rating, en: String, tr: String, color: Color, key: KeyEquivalent) -> some View {
        let due = model.current.map { SRSEngine().rate($0.schedule, as: rating, at: Date()).due.timeIntervalSinceNow } ?? 60
        let duration = due < 3600 ? "\(max(1, Int((due / 60).rounded()))) " + model.t("min", "dk") : "\(max(1, Int((due / 86400).rounded()))) " + model.t("days", "gün")
        return Button { model.rate(rating) } label: {
            VStack(spacing: 4) { Text(model.t(en, tr)).font(.system(size: 12, weight: .semibold)); Text(duration).font(.system(size: 10)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).frame(height: 46)
        }.buttonStyle(ReviewRatingStyle(tint: color, primary: rating == .good)).keyboardShortcut(key, modifiers: [])
    }
    private var symbol: String {
        switch model.kind {
        case .flashcard: return "rectangle.on.rectangle"
        case .speaking: return "mic"
        case .listening: return "headphones"
        case .builder: return "text.word.spacing"
        default: return "questionmark.circle"
        }
    }
}

private struct ReviewRatingStyle: ButtonStyle {
    let tint: Color
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(primary ? tint : Color.primary.opacity(0.85))
            .background(primary ? tint.opacity(configuration.isPressed ? 0.28 : 0.16) : Color.white.opacity(configuration.isPressed ? 0.14 : 0.065), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(primary ? tint.opacity(0.25) : .white.opacity(0.07), lineWidth: 0.5))
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}
