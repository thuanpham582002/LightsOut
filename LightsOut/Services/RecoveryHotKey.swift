import Carbon

/// Carbon hotkeys work while another app is focused, without an event tap.
final class RecoveryHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let recover: () -> Void

    init(recover: @escaping () -> Void) {
        self.recover = recover
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                  eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<RecoveryHotKey>.fromOpaque(context).takeUnretainedValue()
            owner.recover()
            return noErr
        }, 1, &event, context, &handler)
        guard installed == noErr else {
            print("Recovery hotkey handler registration failed: \(installed)")
            return
        }
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_R),
            UInt32(cmdKey | optionKey | controlKey),
            EventHotKeyID(signature: 0x4C4F5554, id: 1),
            GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr { print("Recovery hotkey unavailable: \(status)") }
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
