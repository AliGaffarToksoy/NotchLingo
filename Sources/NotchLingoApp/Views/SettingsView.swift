import SwiftUI
import ServiceManagement
import NotchLingoCore

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(model.t("Make it yours", "Sana göre ayarla")).font(.largeTitle.bold())
            GroupBox(model.t("Language & voice", "Dil ve ses")) {
                VStack(spacing: 16) {
                    Picker("Arayüz / Interface", selection: $model.preferences.language) { Text("Türkçe").tag("tr"); Text("English").tag("en") }
                    Picker(model.t("English voice", "İngilizce ses"), selection: $model.preferences.voice) {
                        Text("American English · US").tag("en-US"); Text("British English · UK").tag("en-GB")
                    }
                    Toggle(model.t("Show extra hints and usage notes", "Ek ipuçlarını ve kullanım notlarını göster"), isOn: $model.preferences.hints)
                    Text(model.t("Every card always includes both English and Turkish meanings.", "Her kartta İngilizce ve Türkçe anlam birlikte bulunur.")).font(.caption).foregroundStyle(.secondary)
                }.padding(12)
            }
            GroupBox(model.t("Daily rhythm", "Günlük düzen")) {
                VStack(spacing: 16) {
                    Stepper(model.t("New cards per day: ", "Günlük yeni kart: ") + "\(model.preferences.newLimit)", value: $model.preferences.newLimit, in: 0...100)
                    Stepper(model.t("Max reviews per day: ", "Günlük en fazla tekrar: ") + "\(model.preferences.reviewLimit)", value: $model.preferences.reviewLimit, in: 0...500, step: 10)
                    Picker(model.t("Session length", "Oturum süresi"), selection: $model.preferences.sessionMinutes) {
                        ForEach([1, 3, 5], id: \.self) { Text("\($0) " + model.t("min", "dk")).tag($0) }
                    }.pickerStyle(.segmented)
                    HStack {
                        Text(model.t("Everyday", "Günlük")); Slider(value: $model.preferences.everydayWeight, in: 0...1, step: 0.1)
                        Text("\(Int(model.preferences.everydayWeight * 100)) / \(100 - Int(model.preferences.everydayWeight * 100))").monospacedDigit()
                        Text(model.t("Tech", "Teknik"))
                    }
                }.padding(12)
            }
            GroupBox(model.t("Exercise modules", "Alıştırmalar")) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading) {
                    ForEach(ExerciseKind.allCases) { kind in
                        Toggle(model.title(kind), isOn: Binding(get: { model.preferences.modules.contains(kind.rawValue) }, set: { value in
                            if value { model.preferences.modules.append(kind.rawValue) }
                            else if model.preferences.modules.count > 1 { model.preferences.modules.removeAll { $0 == kind.rawValue } }
                        })).padding(5)
                    }
                }.padding(12)
            }
            GroupBox(model.t("Gentle reminders", "Küçük hatırlatmalar")) {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(model.t("Enable reminders", "Hatırlatmaları aç"), isOn: $model.preferences.pings)
                        .onChange(of: model.preferences.pings) { enabled in if enabled { NotificationService.request(model: model) } }
                    Stepper(model.t("Every ", "Her ") + "\(model.preferences.interval) " + model.t("minutes", "dakikada"), value: $model.preferences.interval, in: 15...240, step: 15)
                    HStack {
                        Picker(model.t("From", "Başlangıç"), selection: $model.preferences.startHour) { ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) } }
                        Picker(model.t("Until", "Bitiş"), selection: $model.preferences.endHour) { ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) } }
                    }
                    Toggle(model.t("Also show a passive notch ping", "Çentikte pasif soru da göster"), isOn: $model.preferences.directPings)
                    Text(model.t("System notifications respect Focus. Direct notch pings cannot detect Focus reliably; keep this off for Focus-aware reminders. Pings never take keyboard focus.", "Sistem bildirimleri Odak ayarlarına uyar. Doğrudan çentik soruları Odak durumunu güvenilir algılayamaz; Odak'a uyan hatırlatmalar için bu seçeneği kapalı tut. Sorular klavye odağını almaz."))
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(model.t("Pause for 1 hour", "1 saat duraklat")) { model.pause() }
                        if let until = model.preferences.pauseUntil, until > Date() {
                            Text(until, style: .time)
                            Button(model.t("Resume", "Sürdür")) { model.preferences.pauseUntil = nil }
                        }
                    }
                }.padding(12)
            }
            GroupBox(model.t("Keyboard & startup", "Klavye ve başlangıç")) {
                VStack(spacing: 16) {
                    Picker(model.t("Global shortcut", "Genel kısayol"), selection: $model.preferences.hotkeyCode) {
                        Text("⌥⌘L").tag(UInt32(37)); Text("⌥⌘Space").tag(UInt32(49)); Text("⌥⌘N").tag(UInt32(45))
                    }
                    Toggle(model.t("Open at login", "Oturum açıldığında başlat"), isOn: Binding(get: { SMAppService.mainApp.status == .enabled }, set: { value in
                        do {
                            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            model.preferences.launchAtLogin = value
                        } catch { model.error = error.localizedDescription }
                    }))
                    Text(model.t("No account. No telemetry. No cloud sync. Your progress stays on this Mac.", "Hesap yok. Telemetri yok. Bulut eşitlemesi yok. İlerlemen bu Mac'te kalır.")).font(.caption).foregroundStyle(.secondary)
                }.padding(12)
            }
            Button(model.t("Show welcome guide", "Karşılama rehberini göster")) { model.showOnboarding = true }
        }.toggleStyle(.switch)
    }
}

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "text.bubble.fill").font(.system(size: 48)).foregroundStyle(.mint)
            Text(model.t("Welcome to NotchLingo", "NotchLingo'ya hoş geldin")).font(.largeTitle.bold())
            Picker("Dil / Language", selection: $model.preferences.language) { Text("Türkçe").tag("tr"); Text("English").tag("en") }.pickerStyle(.segmented)
            Text(model.t("Learn in small moments: open the top pill, study a few cards, then get back to your day.", "Kısa aralarda öğren: üstteki çentiği aç, birkaç kart çalış ve gününe devam et."))
            Label(model.t("Microphone and speech permission are requested only when you start speaking.", "Mikrofon ve konuşma izinleri yalnızca konuşma çalışmasını başlatınca istenir."), systemImage: "mic")
            Label(model.t("Reminders are off until you enable them. You can snooze anytime.", "Hatırlatmalar sen açana kadar kapalıdır. İstediğin zaman erteleyebilirsin."), systemImage: "bell")
            Label(model.t("All progress is stored locally. Optional AI is off by default.", "Tüm ilerleme yerelde saklanır. İsteğe bağlı yapay zekâ varsayılan olarak kapalıdır."), systemImage: "lock.shield")
            Button(model.t("Let's begin", "Başlayalım")) { model.preferences.onboarding = true; model.showOnboarding = false }
                .buttonStyle(.borderedProminent).tint(.mint).controlSize(.large)
        }.padding(36).frame(width: 520).preferredColorScheme(.dark)
    }
}
