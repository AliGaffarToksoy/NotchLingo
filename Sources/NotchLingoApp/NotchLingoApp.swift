import AppKit
import SwiftUI
import UserNotifications

@main
@MainActor enum NotchLingoApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var model: AppModel?
    private var notch: NotchController?
    private var window: NSWindow?
    private var status: NSStatusItem?
    private var hotkey: Hotkey?
    private var timer: Timer?
    private var lastPing = Date()
    private var pingUntil: Date?
    private var lastHotkey: UInt32?
    private var sleeping = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let model = try AppModel(); self.model = model
            installApplicationMenu()
            notch = NotchController(model: model)
            model.expandPanel = { [weak self] active in self?.notch?.show(expanded: true, userInitiated: active) }
            model.showDashboard = { [weak self] in self?.openDashboard() }
            model.showSettings = { [weak self] in self?.openSettings() }
            model.preferencesChanged = { [weak self] in self?.refreshPreferences() }
            hotkey = Hotkey(); hotkey?.action = { [weak self] in self?.startSession() }
            status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            status?.button?.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "NotchLingo")
            refreshPreferences()
            if Bundle.main.bundleIdentifier != nil { UNUserNotificationCenter.current().delegate = self }
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
            openDashboard()
        } catch {
            let alert = NSAlert(); alert.messageText = "NotchLingo açılamadı / Could not open NotchLingo"
            alert.informativeText = error.localizedDescription + "\nYour local data has not been deleted. / Yerel verilerin silinmedi."
            alert.runModal(); NSApp.terminate(nil)
        }
    }
    private func installApplicationMenu() {
        let t: (String, String) -> String = { [weak self] en, tr in self?.model?.t(en, tr) ?? en }
        let main = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: t("About NotchLingo", "NotchLingo Hakkında"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settings = NSMenuItem(title: t("Settings…", "Ayarlar…"), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self; appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: t("Hide NotchLingo", "NotchLingo’yu Gizle"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: t("Quit NotchLingo", "NotchLingo’dan Çık"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; main.addItem(appItem)
        let editItem = NSMenuItem(); let edit = NSMenu(title: t("Edit", "Düzen"))
        edit.addItem(withTitle: t("Undo", "Geri Al"), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: t("Cut", "Kes"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: t("Copy", "Kopyala"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: t("Paste", "Yapıştır"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: t("Select All", "Tümünü Seç"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit; main.addItem(editItem); NSApp.mainMenu = main
    }
    private func refreshPreferences() {
        guard let model else { return }
        installApplicationMenu()
        let menu = NSMenu()
        func item(_ title: String, _ action: Selector) {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: ""); entry.target = self; menu.addItem(entry)
        }
        item(model.t("Open Dashboard", "Ana ekranı aç"), #selector(openDashboard))
        item(model.t("Start Quick Session", "Hızlı çalışma başlat"), #selector(startSession))
        item(model.t("Pause for 1h", "1 saat duraklat"), #selector(pause))
        item(model.t("Settings", "Ayarlar"), #selector(openSettings))
        menu.addItem(.separator())
        item(model.t("Quit", "Çıkış"), #selector(quit))
        status?.menu = menu
        if lastHotkey != model.preferences.hotkeyCode {
            lastHotkey = model.preferences.hotkeyCode
            if hotkey?.register(code: model.preferences.hotkeyCode, modifiers: model.preferences.hotkeyModifiers) == false {
                model.error = model.t("Shortcut is in use. Choose another in Settings.", "Kısayol kullanımda. Ayarlar'dan başka birini seç.")
            }
        }
    }
    @objc func openDashboard() {
        guard let model else { return }
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1060, height: 760),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "NotchLingo"; window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true; window.toolbarStyle = .unified
            window.contentView = NSHostingView(rootView: DashboardView(model: model))
            window.center(); window.setFrameAutosaveName("NotchLingoDashboard"); self.window = window
        }
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func startSession() { model?.startSession() }
    @objc func pause() { model?.pause(); notch?.collapse() }
    @objc func openSettings() { openDashboard(); NotificationCenter.default.post(name: .openNotchLingoSettings, object: nil) }
    @objc func quit() { NSApp.terminate(nil) }
    @objc private func willSleep() { sleeping = true; model?.endSession(); notch?.hide() }
    @objc private func didWake() { sleeping = false; lastPing = Date(); notch?.show(expanded: false, userInitiated: false) }
    private func tick() {
        guard let model, !sleeping else { return }
        model.tick()
        let now = Date()
        if let pingUntil, now >= pingUntil { self.pingUntil = nil; if model.pingVisible { notch?.collapse() } }
        guard model.preferences.pings, model.preferences.active(at: now), !model.sessionActive, !model.panelExpanded,
              now.timeIntervalSince(lastPing) >= Double(model.preferences.interval * 60), !model.queue().isEmpty else { return }
        lastPing = now
        if Bundle.main.bundleIdentifier != nil { NotificationService.send(model: model) }
        if model.preferences.directPings {
            model.preparePing(); notch?.show(expanded: true, userInitiated: false); pingUntil = now.addingTimeInterval(20)
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor [weak self] in self?.startSession() }
        completionHandler()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openDashboard(); return true }
    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate(); model?.audio.stopAll() }
}
