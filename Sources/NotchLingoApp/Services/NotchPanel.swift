import AppKit
import SwiftUI

final class LearningPanel: NSPanel {
    var acceptsKeyboard = false
    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }
}

@MainActor final class NotchController {
    let panel: LearningPanel
    private let model: AppModel
    private var observer: NSObjectProtocol?
    private var expanded = false
    private var passive = false
    init(model: AppModel) {
        self.model = model
        panel = LearningPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.level = .statusBar; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.layout(animated: false) }
        }
        show(expanded: false, userInitiated: false)
    }
    func show(expanded: Bool, userInitiated: Bool) {
        self.expanded = expanded; passive = expanded && !userInitiated
        model.panelExpanded = expanded; panel.acceptsKeyboard = expanded && userInitiated
        layout(animated: true)
        panel.orderFrontRegardless()
        if panel.acceptsKeyboard { panel.makeKey() }
        else if panel.isKeyWindow { panel.resignKey() }
    }
    func collapse() { model.pingVisible = false; model.audio.stopAll(); show(expanded: false, userInitiated: false) }
    func hide() { model.audio.stopAll(); panel.orderOut(nil) }
    private func layout(animated: Bool) {
        // Prefer a built-in notched display. If absent, use the screen under the pointer.
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        let inset = screen.safeAreaInsets.top
        let width: CGFloat = expanded ? (passive ? 430 : 560) : 360
        let height: CGFloat = expanded ? (passive ? 310 : min(710, screen.frame.height - inset - 90)) + inset : 42 + inset
        panel.contentView = NSHostingView(rootView: NotchView(model: model, safeTop: inset, passive: passive, close: { [weak self] in self?.collapse() }).preferredColorScheme(.dark))
        let rect = NSRect(x: screen.frame.midX - width/2, y: screen.frame.maxY - height, width: width, height: height)
        let animate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if animate {
            NSAnimationContext.runAnimationGroup { context in context.duration = 0.22; panel.animator().setFrame(rect, display: true) }
        } else { panel.setFrame(rect, display: true) }
    }
}

private struct NotchView: View {
    @ObservedObject var model: AppModel
    let safeTop: CGFloat
    let passive: Bool
    let close: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: safeTop)
            if !model.panelExpanded {
                Button {
                    if model.sessionActive { model.expandPanel?(true) } else { model.startSession() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "text.bubble.fill").foregroundStyle(.mint)
                        Text(model.wordOfDay?.term ?? "NotchLingo").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.secondary)
                    }.padding(.horizontal, 20).frame(height: 42).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(model.t("Open NotchLingo quick session", "NotchLingo hızlı çalışmayı aç"))
            } else {
                HStack {
                    Text("NotchLingo").font(.caption.bold()).foregroundStyle(.secondary)
                    Spacer()
                    if !passive {
                        Button { model.showDashboard?() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                            .buttonStyle(.plain).accessibilityLabel(model.t("Open dashboard", "Ana ekranı aç"))
                    }
                    Button(action: close) { Image(systemName: "xmark") }.buttonStyle(.plain).keyboardShortcut(.escape, modifiers: [])
                        .accessibilityLabel(model.t("Collapse panel", "Paneli küçült"))
                }.padding(.horizontal, 22).padding(.top, 12)
                ScrollView {
                    if passive {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(model.t("What does this mean?", "Bu ne anlama geliyor?")).font(.headline)
                            Text(model.pingContent?.term ?? "NotchLingo").font(.title2.bold())
                            if model.pingAnswered {
                                Label(model.pingContent?.definition ?? "", systemImage: model.pingCorrect ? "checkmark.circle.fill" : "arrow.clockwise.circle")
                                    .foregroundStyle(model.pingCorrect ? .mint : .orange)
                                Text(model.pingContent?.turkishMeaning ?? "").font(.callout)
                            } else {
                                ForEach(model.pingChoices, id: \.self) { choice in
                                    Button(choice) { model.answerPing(choice) }.buttonStyle(.bordered)
                                }
                            }
                            HStack {
                                Button(model.t("Start", "Başla")) { model.startSession() }.buttonStyle(.borderedProminent).tint(.mint)
                                Button(model.t("Snooze 1h", "1 saat ertele")) { model.pause(); close() }.buttonStyle(.bordered)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(22)
                    } else if model.sessionActive && model.current != nil {
                        ExerciseView(model: model, audio: model.audio).padding(22)
                    } else {
                        VStack(alignment: .leading, spacing: 18) {
                            Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(.mint)
                            Text(model.sessionActive ? model.t("All caught up for now", "Şimdilik tamam") : model.t("Every small step counts", "Her küçük adım değerli"))
                                .font(.title2.bold())
                            Text(model.t("\(model.sessionCount) cards this session", "Bu oturumda \(model.sessionCount) kart"))
                            if model.sessionActive {
                                Text(model.t("Learning cards will return here when due. Adjust your daily goals for more new cards.", "Öğrenilen kartlar zamanı gelince burada döner. Daha fazla yeni kart için günlük hedeflerini değiştirebilirsin."))
                                    .font(.callout).foregroundStyle(.secondary)
                            } else {
                                Button(model.t("Start a quick session", "Hızlı çalışma başlat")) { model.startSession() }.buttonStyle(.borderedProminent).tint(.mint)
                            }
                            Button(model.t("Open dashboard", "Ana ekranı aç")) { model.showDashboard?() }
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
            .overlay(alignment: .bottom) { Capsule().fill(.white.opacity(0.18)).frame(width: 30, height: 3).padding(.bottom, 6) }
    }
}
