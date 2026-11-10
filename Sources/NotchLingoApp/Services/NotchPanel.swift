import AppKit
import SwiftUI
import Combine
import QuartzCore

final class LearningPanel: NSPanel {
    var acceptsKeyboard = false
    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }
}

/// The SwiftUI tree stays mounted while the AppKit frame follows its measured content.
@MainActor final class PanelPresentation: ObservableObject {
    @Published var topInset: CGFloat = 0
    @Published var cameraWidth: CGFloat = 180
    @Published var bodyHeight: CGFloat = 180
    @Published var maxBodyHeight: CGFloat = 570
    @Published var passive = false
    var onMeasure: ((CGFloat) -> Void)?
    var onCollapse: (() -> Void)?
}

@MainActor final class NotchController {
    let panel: LearningPanel
    private let model: AppModel
    private let presentation = PanelPresentation()
    private var observers: [NSObjectProtocol] = []
    private var expanded = false
    private var screen: NSScreen?
    private var measuredHeight: CGFloat = 180
    private var currentWidth: CGFloat { expanded ? 440 : (presentation.topInset > 0 ? max(360, presentation.cameraWidth + 180) : 300) }
    init(model: AppModel) {
        self.model = model
        panel = LearningPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.level = .statusBar; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        panel.contentView = NSHostingView(rootView: NotchView(model: model, presentation: presentation).preferredColorScheme(.dark))
        presentation.onMeasure = { [weak self] height in
            guard let self, height.isFinite, height > 0, abs(self.measuredHeight - height) > 1 else { return }
            self.measuredHeight = height
            self.resize(animated: true)
        }
        presentation.onCollapse = { [weak self] in self?.collapse() }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.chooseScreen(); self?.resize(animated: false) }
        })
        chooseScreen()
        show(expanded: false, userInitiated: false)
    }
    private func chooseScreen() {
        screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
        guard let screen else { return }
        presentation.topInset = screen.safeAreaInsets.top
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            presentation.cameraWidth = max(120, right.minX - left.maxX)
        } else { presentation.cameraWidth = 0 }
        presentation.maxBodyHeight = min(570, screen.visibleFrame.height - 100)
    }
    func show(expanded: Bool, userInitiated: Bool) {
        self.expanded = expanded; presentation.passive = expanded && !userInitiated
        model.panelExpanded = expanded; panel.acceptsKeyboard = expanded && userInitiated
        chooseScreen(); resize(animated: true); panel.orderFrontRegardless()
        if panel.acceptsKeyboard { panel.makeKey() }
        else if panel.isKeyWindow { panel.resignKey() }
    }
    func collapse() { model.pingVisible = false; model.audio.stopAll(); show(expanded: false, userInitiated: false) }
    func hide() { model.audio.stopAll(); panel.orderOut(nil) }
    private func resize(animated: Bool) {
        guard let screen else { return }
        presentation.bodyHeight = min(max(100, measuredHeight), presentation.maxBodyHeight)
        let height = expanded ? presentation.topInset + 44 + presentation.bodyHeight : max(34, presentation.topInset + 5)
        let rect = NSRect(x: screen.frame.midX - currentWidth / 2, y: screen.frame.maxY - height, width: currentWidth, height: height)
        guard abs(panel.frame.width - rect.width) > 0.5 || abs(panel.frame.height - rect.height) > 0.5 || panel.frame.origin != rect.origin else { return }
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(rect, display: true)
            }
        } else { panel.setFrame(rect, display: true) }
    }
    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
}

private struct ContentHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct NotchView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var presentation: PanelPresentation
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        VStack(spacing: 0) {
            if model.panelExpanded {
                Color.clear.frame(height: presentation.topInset)
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if presentation.passive { ping }
                        else if model.sessionActive && model.current != nil { ExerciseView(model: model, audio: model.audio) }
                        else { completion }
                    }
                    .padding(.horizontal, 22).padding(.top, 5).padding(.bottom, 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(GeometryReader { proxy in Color.clear.preference(key: ContentHeight.self, value: proxy.size.height) })
                }
                .scrollIndicators(.hidden)
                .frame(height: presentation.bodyHeight)
                .onPreferenceChange(ContentHeight.self) { height in
                    DispatchQueue.main.async { presentation.onMeasure?(height) }
                }
            } else { collapsed }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background {
            if reduceTransparency { Color.black }
            else { Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(0.93)) }
        }
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: model.panelExpanded ? 24 : 15, bottomTrailingRadius: model.panelExpanded ? 24 : 15))
        .overlay(alignment: .bottom) {
            if model.panelExpanded { Capsule().fill(.white.opacity(0.15)).frame(width: 28, height: 3).padding(.bottom, 6).allowsHitTesting(false) }
        }
        .environment(\.locale, Locale(identifier: model.preferences.language))
        .tint(LingoStyle.accent)
        .onExitCommand { presentation.onCollapse?() }
    }
    private var collapsed: some View {
        Button {
            if model.sessionActive { model.expandPanel?(true) } else { model.startSession() }
        } label: {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: model.sessionActive ? "waveform" : "character.bubble.fill").font(.system(size: 13, weight: .medium)).foregroundStyle(.teal)
                    if presentation.topInset == 0 { Text("NotchLingo").font(.system(size: 12, weight: .medium)) }
                    Spacer(minLength: 0)
                }
                if presentation.topInset > 0 { Color.clear.frame(width: presentation.cameraWidth + 16) }
                HStack(spacing: 6) {
                    if presentation.topInset == 0 { Spacer(minLength: 0) }
                    Text(model.sessionActive ? "\(model.secondsLeft / 60):\(String(format: "%02d", model.secondsLeft % 60))" : (model.wordOfDay?.term ?? "English"))
                        .font(.system(size: 11, weight: .medium)).lineLimit(1).truncationMode(.tail).foregroundStyle(.white.opacity(0.8))
                }.frame(maxWidth: .infinity, alignment: .trailing)
            }.padding(.horizontal, 14).frame(height: max(34, presentation.topInset + 5)).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .help(model.wordOfDay.map { "\($0.term) · \($0.turkishMeaning)" } ?? "NotchLingo")
            .accessibilityLabel(model.t("Open quick session. Word of the day: ", "Hızlı çalışmayı aç. Günün kelimesi: ") + (model.wordOfDay?.term ?? ""))
    }
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "character.bubble.fill").font(.system(size: 12)).foregroundStyle(.teal)
            Text("NotchLingo").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            Spacer()
            if !presentation.passive {
                QuietIconButton(symbol: "macwindow", label: model.t("Open dashboard", "Ana ekranı aç")) { model.showDashboard?() }
            }
            QuietIconButton(symbol: "chevron.up", label: model.t("Collapse", "Küçült")) { presentation.onCollapse?() }
        }.padding(.horizontal, 16).frame(height: 44)
    }
    private var ping: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.t("A quick recall", "Kısa bir hatırlama")).font(.caption).foregroundStyle(.secondary)
            Text(model.pingContent?.term ?? "NotchLingo").font(.system(size: 23, weight: .semibold))
            if model.pingAnswered {
                Label(model.pingContent?.definition ?? "", systemImage: model.pingCorrect ? "checkmark.circle.fill" : "arrow.clockwise.circle")
                    .foregroundStyle(model.pingCorrect ? .teal : .orange)
                Text(model.pingContent?.turkishMeaning ?? "").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(model.pingChoices, id: \.self) { choice in
                    Button { model.answerPing(choice) } label: {
                        Text(choice).font(.callout).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading).padding(10)
                            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
            }
            HStack {
                Button(model.t("Continue", "Devam et")) { model.startSession() }.buttonStyle(.bordered)
                Spacer()
                Button(model.t("Snooze 1 hour", "1 saat ertele")) { model.pause(); presentation.onCollapse?() }.buttonStyle(.plain).foregroundStyle(.secondary).font(.caption)
            }
        }
    }
    private var completion: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 28)).foregroundStyle(.teal).padding(.top, 4)
            Text(model.sessionActive ? model.t("You're all caught up.", "Şimdilik tamam.") : model.t("A little progress, made.", "Bir adım daha attın.")).font(.system(size: 22, weight: .semibold))
            Text(model.t("\(model.sessionCount) cards this session", "Bu oturumda \(model.sessionCount) kart")).foregroundStyle(.secondary).font(.callout)
            if model.sessionActive {
                Text(model.t("Learning cards return when due. You can leave this open or come back later.", "Öğrenilen kartlar zamanı gelince döner. Burayı açık bırakabilir veya sonra dönebilirsin."))
                    .font(.callout).foregroundStyle(.secondary)
                Button(model.t("Done for now", "Şimdilik bitir")) { model.endSession(); presentation.onCollapse?() }.buttonStyle(.borderedProminent)
            } else {
                HStack {
                    Button(model.t("Another session", "Bir oturum daha")) { model.startSession() }.buttonStyle(.bordered)
                    Spacer()
                    Button(model.t("Done", "Bitti")) { presentation.onCollapse?() }.buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
