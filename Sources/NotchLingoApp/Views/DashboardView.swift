import SwiftUI
import Charts
import NotchLingoCore
import NotchLingoStorage

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @State private var page: String? = "home"
    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                Section(model.t("Learn", "Öğren")) {
                    Label(model.t("Today", "Bugün"), systemImage: "sun.max").tag("home")
                    Label(model.t("Library", "Kütüphane"), systemImage: "rectangle.stack").tag("decks")
                    Label(model.t("Practice", "Pekiştir"), systemImage: "arrow.clockwise").tag("weak")
                }
                Section {
                    Label(model.t("AI workshop", "Yapay zekâ atölyesi"), systemImage: "sparkles").tag("ai")
                    Label(model.t("Settings", "Ayarlar"), systemImage: "gearshape").tag("settings")
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 7) {
                    Image(systemName: "lock.shield").foregroundStyle(.secondary)
                    Text(model.t("Stored on this Mac", "Bu Mac'te saklanır")).foregroundStyle(.secondary)
                    Spacer()
                }.font(.caption).padding(16)
            }
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch page {
                    case "decks": DeckBrowser(model: model)
                    case "weak": weakWords
                    case "settings": SettingsView(model: model)
                    case "ai": AIWorkshopView(model: model)
                    default: overview
                    }
                }.padding(28).frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(LingoStyle.page)
            .navigationTitle(pageTitle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if model.sessionActive { model.expandPanel?(true) } else { model.startSession() }
                    } label: { Label(model.t("Study", "Çalış"), systemImage: "play.fill") }
                    .help(model.t("Open a quick session in the notch", "Çentikte hızlı çalışma aç"))
                }
            }
        }
        .tint(LingoStyle.accent)
        .environment(\.locale, Locale(identifier: model.preferences.language))
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $model.showOnboarding) { OnboardingView(model: model) }
        .alert(model.t("Something needs attention", "Bir sorun oluştu"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button(model.t("OK", "Tamam")) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .alert(model.t("Done", "Tamamlandı"), isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button(model.t("OK", "Tamam")) { model.notice = nil }
        } message: { Text(model.notice ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: .openNotchLingoSettings)) { _ in page = "settings" }
    }
    private var pageTitle: String {
        switch page {
        case "decks": return model.t("Library", "Kütüphane")
        case "weak": return model.t("Practice", "Pekiştir")
        case "settings": return model.t("Settings", "Ayarlar")
        case "ai": return model.t("AI workshop", "Yapay zekâ atölyesi")
        default: return model.t("Today", "Bugün")
        }
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide)).font(.subheadline).foregroundStyle(.secondary)
                    Text(model.t("A little, every day.", "Her gün, biraz daha.")).font(.system(size: 28, weight: .bold))
                }
                Spacer()
                if model.streak > 0 {
                    Label(model.t("\(model.streak)-day streak", "\(model.streak) günlük seri"), systemImage: "flame.fill")
                        .font(.subheadline.weight(.medium)).foregroundStyle(.orange)
                }
            }
            HStack(spacing: 0) {
                metric(model.t("Studied today", "Bugün çalışılan"), "\(model.todayEvents.count)", model.t("cards", "kart"))
                Divider().frame(height: 44).padding(.horizontal, 20)
                metric(model.t("Recall", "Hatırlama"), StudyStatistics.retention(model.activity).map { "\(Int($0 * 100))%" } ?? "—", model.t("scheduled reviews", "planlı tekrarlar"))
                Divider().frame(height: 44).padding(.horizontal, 20)
                metric(model.t("Time today", "Bugünkü süre"), "\(Int(model.todayEvents.reduce(0) { $0 + $1.durationSeconds } / 60))", model.t("minutes", "dakika"))
            }.padding(.vertical, 4)
            if let word = model.wordOfDay {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label(model.t("WORD OF THE DAY", "GÜNÜN KELİMESİ"), systemImage: "sparkle")
                            .font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(LingoStyle.accent)
                        Spacer()
                        Text(word.cefr.rawValue).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                    HStack(alignment: .center) {
                        Text(word.term).font(.system(size: 30, weight: .semibold)).textSelection(.enabled)
                        Spacer(minLength: 20)
                        QuietIconButton(symbol: "speaker.wave.2", label: model.t("Listen", "Dinle")) { model.audio.speak(word.term, locale: model.preferences.voice) }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(word.definition).font(.body)
                        Text(word.turkishMeaning).font(.body).foregroundStyle(.secondary)
                    }
                    Divider()
                    HStack {
                        Text(model.t("One small session. A lasting habit.", "Kısa bir çalışma. Kalıcı bir alışkanlık.")).font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            if model.sessionActive { model.expandPanel?(true) } else { model.startSession() }
                        } label: {
                            Label(model.sessionActive ? model.t("Continue", "Devam et") : model.t("Study for \(model.preferences.sessionMinutes) min", "\(model.preferences.sessionMinutes) dk çalış"), systemImage: "play.fill")
                        }.buttonStyle(.borderedProminent).controlSize(.large)
                    }
                }.padding(6).cardSurface()
            }
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(model.t("Daily goals", "Günlük hedefler")).font(.headline)
                    goal(model.t("New cards", "Yeni kartlar"), model.budget.introducedToday, model.preferences.newLimit)
                    goal(model.t("Reviews", "Tekrarlar"), model.budget.reviewedToday, model.preferences.reviewLimit)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.t("Your library", "Kütüphanen")).font(.headline)
                    stateRow(model.t("New", "Yeni"), count: model.cards.filter { $0.schedule.state == .new }.count, color: .secondary)
                    stateRow(model.t("Learning", "Öğreniliyor"), count: model.cards.filter { $0.schedule.state == .learning || $0.schedule.state == .relearning }.count, color: .orange)
                    stateRow(model.t("Reviewing", "Tekrar ediliyor"), count: model.cards.filter { $0.schedule.state == .review && !$0.schedule.isMature }.count, color: .blue)
                    stateRow(model.t("Mature", "Kalıcı"), count: model.cards.filter { $0.schedule.isMature }.count, color: .teal)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.fixedSize(horizontal: false, vertical: true).cardSurface()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(model.t("Activity", "Etkinlik")).font(.headline)
                    Spacer()
                    Text(model.t("Last 30 days", "Son 30 gün")).font(.caption).foregroundStyle(.secondary)
                }
                Chart(days, id: \.date) { item in
                    BarMark(x: .value(model.t("Day", "Gün"), item.date, unit: .day), y: .value(model.t("Cards", "Kart"), item.count))
                        .foregroundStyle(LingoStyle.accent.gradient).cornerRadius(3)
                }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
                .frame(height: 130)
                .overlay {
                    if model.events.isEmpty {
                        Text(model.t("Your first session starts the story.", "İlk çalışmanla birlikte dolmaya başlayacak."))
                            .font(.callout).foregroundStyle(.secondary).padding(12).background(.regularMaterial, in: Capsule())
                    }
                }
                .accessibilityLabel(model.t("Daily study activity for thirty days", "Otuz günlük çalışma etkinliği"))
            }.cardSurface()
        }
    }
    private var weakWords: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(model.t("A second look helps.", "Bir kez daha bakmak iyi gelir.")).font(.title.bold())
            Text(model.t("Words missed eight times or more. Practice at your own pace, outside daily limits.", "Sekiz kez veya daha fazla unuttuğun kelimeler. Günlük sınırların dışında, kendi hızında çalış.")).foregroundStyle(.secondary)
            if !model.cards.contains(where: { $0.schedule.isLeech }) {
                ContentUnavailableView(model.t("Nothing to revisit yet", "Şimdilik pekiştirilecek kelime yok"), systemImage: "checkmark.circle", description: Text(model.t("Tricky words will appear here as you learn.", "Öğrenirken zorlandığın kelimeler burada görünecek.")))
                    .frame(minHeight: 240)
            } else {
                Button(model.t("Practice these words", "Bu kelimeleri çalış")) { model.startSession(weakOnly: true) }.buttonStyle(.borderedProminent)
                ForEach(model.cards.filter { $0.schedule.isLeech }) { card in
                    HStack { Text(card.term).font(.headline); Spacer(); Text(model.t("\(card.misses) misses", "\(card.misses) unutma")).font(.callout).foregroundStyle(.secondary) }.cardSurface()
                }
            }
        }
    }
    private func metric(_ title: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value).font(.system(size: 28, weight: .semibold)).monospacedDigit()
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func stateRow(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) { Circle().fill(color).frame(width: 5, height: 5); Text(label); Spacer(); Text("\(count)").monospacedDigit().foregroundStyle(.secondary) }.font(.callout)
    }
    private func goal(_ title: String, _ value: Int, _ total: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(title); Spacer(); Text("\(value) / \(total)").monospacedDigit().foregroundStyle(.secondary) }.font(.callout)
            ProgressView(value: Double(min(value, total)), total: Double(max(1, total)))
        }
    }
    private var days: [(date: Date, count: Int)] {
        (0..<30).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Calendar.current.startOfDay(for: Date()))!
            return (date, model.events.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.count)
        }
    }
}
extension Notification.Name { static let openNotchLingoSettings = Notification.Name("openNotchLingoSettings") }
