import Foundation
import NotchLingoCore

struct Preferences: Codable {
    var language = "tr"
    var voice = "en-US"
    var hints = true
    var newLimit = 10
    var reviewLimit = 100
    var everydayWeight = 0.5
    var sessionMinutes = 3
    var modules = ExerciseKind.allCases.map(\.rawValue)
    var pings = false
    var directPings = false
    var interval = 60
    var startHour = 9
    var endHour = 21
    var pauseUntil: Date?
    var hotkeyCode: UInt32 = 37 // L
    var hotkeyModifiers: UInt32 = 2304 // command + option (Carbon)
    var onboarding = false
    var aiEnabled = false
    var aiProvider = "ollama"
    var aiModel = "llama3.2"
    var aiURL = "http://localhost:11434"
    var launchAtLogin = false

    static func load() -> Preferences {
        guard let data = UserDefaults.standard.data(forKey: "preferences.v1"),
              let value = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        return value
    }
    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: "preferences.v1") }
    }
    func active(at date: Date, calendar: Calendar = .current) -> Bool {
        if let pauseUntil, pauseUntil > date { return false }
        let hour = calendar.component(.hour, from: date)
        if startHour == endHour { return true }
        return startHour < endHour ? hour >= startHour && hour < endHour : hour >= startHour || hour < endHour
    }
}
