import SwiftUI
import NotchLingoCore

struct AIWorkshopView: View {
    @ObservedObject var model: AppModel
    @State private var key = ""
    @State private var input = ""
    @State private var result = ""
    @State private var taskKind = "feedback"
    @State private var busy = false
    @State private var work: Task<Void, Never>?
    @State private var generated: DeckDocument?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(model.t("A little extra help", "Biraz ek destek")).font(.largeTitle.bold())
            Toggle(model.t("Enable optional AI", "İsteğe bağlı yapay zekâyı aç"), isOn: $model.preferences.aiEnabled)
            Text(model.t("Only text you submit here is sent to the selected provider. Cloud providers may charge your API account. Ollama stays on localhost. Learning works without any of these.", "Yalnızca burada gönderdiğin metin seçilen sağlayıcıya iletilir. Bulut sağlayıcıları API hesabını ücretlendirebilir. Ollama yerel bilgisayarda çalışır. Öğrenme bunların hiçbiri olmadan da çalışır."))
                .font(.callout).foregroundStyle(.secondary)
            GroupBox {
                VStack(spacing: 14) {
                    Picker(model.t("Provider", "Sağlayıcı"), selection: $model.preferences.aiProvider) {
                        Text("Ollama · local").tag("ollama"); Text("OpenAI").tag("openai"); Text("Anthropic").tag("anthropic")
                    }.onChange(of: model.preferences.aiProvider) { provider in
                        key = ""; model.preferences.aiModel = provider == "ollama" ? "llama3.2" : ""
                    }
                    TextField(model.t("Model name from your provider", "Sağlayıcındaki model adı"), text: $model.preferences.aiModel).textFieldStyle(.roundedBorder)
                    if model.preferences.aiProvider == "ollama" {
                        TextField("Ollama URL", text: $model.preferences.aiURL).textFieldStyle(.roundedBorder)
                    } else {
                        HStack {
                            SecureField("API key", text: $key)
                            Button(model.t("Save in Keychain", "Anahtar Zinciri'ne kaydet")) {
                                do { try KeyStore.save(key, provider: model.preferences.aiProvider); key = ""; model.notice = model.t("Key saved.", "Anahtar kaydedildi.") }
                                catch { model.error = error.localizedDescription }
                            }.disabled(key.isEmpty)
                            Button(model.t("Remove key", "Anahtarı kaldır")) {
                                do { try KeyStore.save("", provider: model.preferences.aiProvider); model.notice = model.t("Key removed.", "Anahtar kaldırıldı.") }
                                catch { model.error = error.localizedDescription }
                            }
                        }
                    }
                }.padding(12)
            }.disabled(busy)
            Picker(model.t("Task", "İşlem"), selection: $taskKind) {
                Text(model.t("Feedback", "Geri bildirim")).tag("feedback")
                Text(model.t("Examples", "Örnekler")).tag("examples")
                Text(model.t("Generate cards", "Kart üret")).tag("cards")
            }.pickerStyle(.segmented).disabled(busy)
            TextEditor(text: $input).font(.body).frame(height: 120).padding(8)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary.opacity(0.3)))
                .accessibilityLabel(model.t("Sentence or topic", "Cümle veya konu"))
            HStack {
                Button(model.t("Send to selected provider", "Seçili sağlayıcıya gönder")) { run() }
                    .buttonStyle(.borderedProminent).tint(.mint).disabled(!model.preferences.aiEnabled || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                if busy {
                    ProgressView().controlSize(.small)
                    Button(model.t("Cancel", "İptal")) { work?.cancel(); busy = false }
                }
            }
            if !result.isEmpty { Text(result).textSelection(.enabled).cardSurface() }
            if let generated {
                Button(model.t("Import \(generated.cards.count) reviewed cards", "İncelediğim \(generated.cards.count) kartı içe aktar")) {
                    do { try model.store.importDecks([generated]); try model.reload(); self.generated = nil; model.notice = model.t("Cards imported.", "Kartlar içe aktarıldı.") }
                    catch { model.error = error.localizedDescription }
                }
            }
        }.onDisappear { work?.cancel() }
    }
    private func run() {
        busy = true; result = ""; generated = nil
        let settings = model.preferences
        let prompt: String
        if taskKind == "cards" {
            prompt = """
            Create 5 original English-learning cards for a Turkish speaker about: \(input).
            Return ONLY a JSON deck with schemaVersion 1, id UUID, name, track (everyday or techWork), cards.
            Each card: id UUID, term, partOfSpeech, cefr (A1-C1), definition in simple English, turkishMeaning,
            examples (2 natural sentences each highlighting the exact term with **double asterisks**),
            ipaUS, ipaUK, note, tags (nonempty array of unique strings). Use valid UUIDs. No code fences.
            """
        } else if taskKind == "examples" {
            prompt = "Give 3 natural English example sentences and Turkish translations for: \(input). Explain register briefly in \(settings.language == "tr" ? "Turkish" : "English")."
        } else {
            prompt = "Help a Turkish speaker improve this English sentence. Explain grammar and naturalness, then give a better version. Explain in \(settings.language == "tr" ? "Turkish" : "English"). Text: \(input)"
        }
        let expectsDeck = taskKind == "cards"
        work = Task { @MainActor in
            defer { busy = false }
            do {
                let response = try await ConfiguredAIProvider(preferences: settings).complete(prompt)
                try Task.checkCancellation()
                result = response
                if expectsDeck { generated = try DeckCodec.decode(Data(response.utf8)) }
            } catch is CancellationError { }
            catch { model.error = error.localizedDescription }
        }
    }
}
