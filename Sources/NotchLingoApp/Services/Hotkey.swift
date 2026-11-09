import Carbon
import Foundation

/// Carbon's registered hotkey API does not require Accessibility or keylogging permissions.
@MainActor final class Hotkey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer in
            guard let pointer else { return OSStatus(eventNotHandledErr) }
            let hotkey = Unmanaged<Hotkey>.fromOpaque(pointer).takeUnretainedValue()
            Task { @MainActor in hotkey.action?() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(code: UInt32, modifiers: UInt32) -> Bool {
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        let id = EventHotKeyID(signature: OSType(0x4E4C4E47), id: 1)
        return RegisterEventHotKey(code, modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr
    }
    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
