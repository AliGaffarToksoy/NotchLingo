import SwiftUI
import NotchLingoCore
import NotchLingoStorage

struct DeckBrowser: View {
    @ObservedObject var model: AppModel
    @State private var search = ""
    @State private var tag = ""
    @State private var deck = ""
    private var entries: [(stored: StoredCard, content: CardContent)] {
        model.cards.compactMap { stored in (try? stored.content()).map { (stored, $0) } }
    }
    private var visible: [(stored: StoredCard, content: CardContent)] {
        entries.filter { entry in
            (deck.isEmpty || entry.stored.deckID.uuidString == deck) && (tag.isEmpty || entry.content.tags.contains(tag)) &&
            (search.isEmpty || [entry.content.term, entry.content.definition, entry.content.turkishMeaning].contains { $0.localizedCaseInsensitiveContains(search) })
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(model.t("Words for every part of your day.", "Günün her anı için kelimeler.")).font(.title.bold())
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(model.t("Search words or meanings", "Kelime veya anlam ara"), text: $search).textFieldStyle(.plain)
            }.padding(10).background(LingoStyle.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(LingoStyle.separator, lineWidth: 0.5))
            HStack {
                Picker(model.t("Deck", "Deste"), selection: $deck) {
                    Text(model.t("All decks", "Tüm desteler")).tag("")
                    ForEach(model.decks) { Text($0.name).tag($0.id.uuidString) }
                }.frame(maxWidth: 260)
                Picker(model.t("Tag", "Etiket"), selection: $tag) {
                    Text(model.t("All tags", "Tüm etiketler")).tag("")
                    ForEach(Array(Set(entries.flatMap { $0.content.tags })).sorted(), id: \.self) { Text($0).tag($0) }
                }.frame(maxWidth: 200)
                Spacer()
            }
            HStack {
                Text("\(visible.count) " + model.t("cards", "kart")).foregroundStyle(.secondary)
                Spacer()
                Button(model.t("Import JSON / CSV", "JSON / CSV içe aktar")) { model.importFile() }
                Menu(model.t("Export", "Dışa aktar")) {
                    Button(model.t("All decks as CSV", "Tüm desteler CSV")) { model.exportFile(csv: true) }
                    ForEach(model.decks) { item in
                        Button(item.name + " · JSON") { model.exportFile(csv: false, deckID: item.id) }
                    }
                }
            }
            if visible.isEmpty {
                ContentUnavailableView.search(text: search)
            }
            LazyVStack(spacing: 8) {
                ForEach(visible, id: \.stored.id) { entry in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(entry.content.definition)
                            Text(entry.content.turkishMeaning).foregroundStyle(LingoStyle.accent)
                            ForEach(entry.content.examples, id: \.self) { example in
                                Text((try? AttributedString(markdown: example)) ?? AttributedString(example))
                            }
                            Text(entry.content.ipaUS + " · " + entry.content.ipaUK).foregroundStyle(.secondary)
                            if let note = entry.content.note { Text(note).font(.callout).foregroundStyle(.secondary) }
                            HStack {
                                Text(entry.content.tags.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button { model.audio.speak(entry.content.term, locale: model.preferences.voice) }
                                label: { Label(model.t("Listen", "Dinle"), systemImage: "speaker.wave.2") }
                            }
                        }.padding(.top, 12).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                    } label: {
                        HStack { Text(entry.content.term).font(.headline); Spacer(); Text(entry.content.cefr.rawValue).font(.caption).foregroundStyle(LingoStyle.accent) }
                    }.cardSurface()
                }
            }
        }
    }
}
