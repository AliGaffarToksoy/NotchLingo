import SwiftUI
import Charts
import NotchLingoCore
import NotchLingoStorage

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @State private var page = "home"
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 10) {
                    Image(systemName: "text.bubble.fill").font(.title).foregroundStyle(.mint)
                    Text("NotchLingo").font(.title2.bold())
                }.padding(.top, 20)
                VStack(spacing: 6) {
                    navigation("home", "Overview", "Genel bakış", "square.grid.2x2")
                    navigation("decks", "Your decks", "Destelerin", "rectangle.stack")
                    navigation("weak", "Extra practice", "Ek çalışma", "flame")
                    navigation("ai", "AI workshop", "Yapay zekâ", "sparkles")
                    navigation("settings", "Settings", "Ayarlar", "slider.horizontal.3")
                }
                Spacer()
                Text(model.t("A little English. Every day.", "Her gün biraz İngilizce."))
                    .font(.callout).foregroundStyle(.secondary)
                Label(model.t("Local & private", "Yerel ve özel"), systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.mint)
            }.padding(20).frame(minWidth: 200).background(Color(red: 0.06, green: 0.09, blue: 0.13))
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
                }.padding(32).frame(maxWidth: 1000, alignment: .leading)
            }.background(Color(red: 0.08, green: 0.11, blue: 0.16))
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 880, minHeight: 640)
        .sheet(isPresented: $model.showOnboarding) { OnboardingView(model: model) }
        .alert(model.t("Something needs attention", "Bir sorun oluştu"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button(model.t("OK", "Tamam")) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .alert(model.t("Done", "Tamamlandı"), isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button(model.t("OK", "Tamam")) { model.notice = nil }
        } message: { Text(model.notice ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: .openNotchLingoSettings)) { _ in page = "settings" }
    }
    private func navigation(_ id: String, _ en: String, _ tr: String, _ icon: String) -> some View {
        Button { page = id } label: {
            Label(model.t(en, tr), systemImage: icon).frame(maxWidth: .infinity, alignment: .leading)
                .padding(12).background(page == id ? Color.mint.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(page == id ? .mint : .white.opacity(0.75))
        }.buttonStyle(.plain)
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.t("Make a little progress.", "Bugün bir adım daha.")).font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(model.t("English that fits between your tasks.", "İşlerinin arasına sığan İngilizce.")).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.startSession() } label: { Label(model.t("Quick session", "Hızlı çalışma"), systemImage: "play.fill") }
                    .buttonStyle(.borderedProminent).tint(.mint).controlSize(.large)
            }
            HStack(spacing: 14) {
                stat(model.t("Today", "Bugün"), "\(model.todayEvents.count)", "checkmark.circle")
                stat(model.t("Day streak", "Günlük seri"), "\(model.streak)", "flame")
                stat(model.t("Recall", "Hatırlama"), StudyStatistics.retention(model.activity).map { "\(Int($0 * 100))%" } ?? "—", "brain")
                stat(model.t("Minutes today", "Bugünkü dakika"), "\(Int(model.todayEvents.reduce(0) { $0 + $1.durationSeconds } / 60))", "clock")
            }
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(model.t("Daily goals", "Günlük hedefler")).font(.headline)
                    goal(model.t("New cards", "Yeni kartlar"), model.budget.introducedToday, model.preferences.newLimit)
                    goal(model.t("Reviews", "Tekrarlar"), model.budget.reviewedToday, model.preferences.reviewLimit)
                    HStack {
                        Text(model.t("New", "Yeni") + ": \(model.cards.filter { $0.schedule.state == .new }.count)")
                        Text(model.t("Learning", "Öğreniliyor") + ": \(model.cards.filter { $0.schedule.state == .learning || $0.schedule.state == .relearning }.count)")
                        Text(model.t("Mature", "Kalıcı") + ": \(model.cards.filter { $0.schedule.isMature }.count)")
                    }.font(.caption).foregroundStyle(.secondary)
                }.cardSurface()
                if let word = model.wordOfDay {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(model.t("Word of the day", "Günün kelimesi"), systemImage: "sun.max").font(.caption).foregroundStyle(.mint)
                        Text(word.term).font(.title2.bold())
                        Text(word.definition).font(.callout)
                        Text(word.turkishMeaning).font(.callout).foregroundStyle(.secondary)
                        Button { model.audio.speak(word.term, locale: model.preferences.voice) }
                        label: { Label(model.t("Listen", "Dinle"), systemImage: "speaker.wave.2") }.buttonStyle(.bordered)
                    }.cardSurface()
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                Text(model.t("Last 30 days", "Son 30 gün")).font(.headline)
                Chart(days, id: \.date) { item in
                    BarMark(x: .value("Day", item.date, unit: .day), y: .value("Reviews", item.count))
                        .foregroundStyle(.mint.gradient).cornerRadius(3)
                }.frame(height: 180).accessibilityLabel(model.t("Daily study activity for the last thirty days", "Son otuz günlük çalışma etkinliği"))
            }.cardSurface()
            if model.sessionActive {
                VStack(alignment: .leading, spacing: 16) {
                    if model.current != nil { ExerciseView(model: model, audio: model.audio) }
                    else { waiting }
                }.cardSurface()
            }
        }
    }
    private var waiting: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.t("You're caught up for now.", "Şimdilik sıradaki kartları bitirdin.")).font(.headline)
            Text(model.t("Learning cards return when due. You can adjust daily goals in Settings.", "Öğrenilen kartlar zamanı gelince döner. Günlük hedefleri Ayarlar'dan değiştirebilirsin.")).foregroundStyle(.secondary)
            Button(model.t("End session", "Oturumu bitir")) { model.endSession() }
        }
    }
    private var weakWords: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.t("Give tricky words another chance.", "Zor kelimelere bir şans daha.")).font(.largeTitle.bold())
            Text(model.t("Cards with eight or more misses appear here. Extra practice bypasses daily limits.", "Sekiz veya daha fazla kez unuttuğun kartlar burada görünür. Ek çalışma günlük sınırların dışındadır.")).foregroundStyle(.secondary)
            Button(model.t("Practice weak words", "Zor kelimeleri çalış")) { model.startSession(weakOnly: true) }
                .buttonStyle(.borderedProminent).tint(.mint).disabled(!model.cards.contains { $0.schedule.isLeech })
            ForEach(model.cards.filter { $0.schedule.isLeech }) { card in
                HStack {
                    Text(card.term).font(.headline)
                    Spacer()
                    Text(model.t("\(card.misses) misses", "\(card.misses) unutma")).foregroundStyle(.orange)
                }.cardSurface()
            }
        }
    }
    private func stat(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.mint)
            Text(value).font(.system(size: 30, weight: .bold, design: .rounded))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }
    private func goal(_ title: String, _ value: Int, _ total: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(title); Spacer(); Text("\(value) / \(total)").foregroundStyle(.secondary) }.font(.callout)
            ProgressView(value: Double(min(value, total)), total: Double(max(1, total))).tint(.mint)
        }
    }
    private var days: [(date: Date, count: Int)] {
        (0..<30).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Calendar.current.startOfDay(for: Date()))!
            return (date, model.events.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.count)
        }
    }
}

extension View {
    func cardSurface() -> some View {
        padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.06)))
    }
}
extension Notification.Name { static let openNotchLingoSettings = Notification.Name("openNotchLingoSettings") }
