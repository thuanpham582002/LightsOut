//
//  DisplaysViewModel.swift
//  BlackoutTest

import CoreGraphics
import ColorSync
import SwiftUI

@_silgen_name("CGSConfigureDisplayEnabled")
func CGSConfigureDisplayEnabled(_ cid: CGDisplayConfigRef, _ display: UInt32, _ enabled: Bool) -> Int

private let displayTopologyChanged = Notification.Name("LightsOut.displayTopologyChanged")
private let displayReconfigurationCallback: CGDisplayReconfigurationCallBack = { id, flags, _ in
    guard !flags.contains(.beginConfigurationFlag) else { return }
    // Preserve the removal event even if a dock reconnects before the main queue runs.
    let removed = flags.contains(.removeFlag)
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: displayTopologyChanged, object: nil,
                                        userInfo: ["id": id, "removed": removed])
    }
}

class DisplaysViewModel: ObservableObject {
    @Published var displays: [DisplayInfo] = []
    private var gammaService = GammaUpdateService()
    private var arrengementCache = DisplayArrangementCacheService()
    private var stateStore = DisplayStateStore()
    private var preferences = DisplayPreferenceStore()
    private var preferencePolicy = DisplayPreferenceRestorePolicy()
    private var automaticRestoreEnabled = true
    private var systemSleeping = false
    private var sessionLocked = false
    private var sessionInactive = false
    
    private var safetyTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var lockObservers: [NSObjectProtocol] = []
    private var recoveryIDs: Set<CGDirectDisplayID> = []
    private var anchors: Set<CGDirectDisplayID> = []
    private var recovering = false
    private var attemptingRecovery = false
    private var recoveryDeadline = RecoveryDeadline()
    private var blackoutIDs: Set<CGDirectDisplayID> = []
    private var lastRecoveryAttempt = Date.distantPast

    init() {
        displays = stateStore.load()
        let migrationKey = "trueDisconnectBuiltInPreferenceV1"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            let builtInUUIDs = Set(displays.filter(\.isBuiltIn).compactMap(\.uuid))
            let migrated = DisplayPreferenceMigration.trueDisconnectForBuiltIn(
                preferences.entries, builtInUUIDs: builtInUUIDs
            )
            if preferences.replace(migrated) {
                UserDefaults.standard.set(true, forKey: migrationKey)
            }
        }
        for display in displays where display.uuid == nil {
            display.isBuiltIn = CGDisplayIsBuiltin(display.id) != 0
        }
        gammaService.restoreAll()
        gammaService.canBlackout = { [weak self] id in
            guard let self, !self.recovering,
                  let display = self.displays.first(where: { $0.id == id }),
                  let uuid = display.uuid, uuid == self.displayUUID(id) else { return false }
            return !self.visibleDisplayIDs(excluding: id).isEmpty
        }
        gammaService.onFailure = { [weak self] in
            guard let self else { return }
            for display in self.displays where self.blackoutIDs.contains(display.id) {
                if let uuid = display.uuid { self.preferencePolicy.failed(uuid, onlineUUIDs: self.onlineUUIDs()) }
            }
            self.forceRecovery(preservePreferences: true)
        }
        fetchDisplays()
        startSafetyMonitoring()
        // Re-evaluate after the live inventory is reconciled. A previous build
        // could persist `active` while the panel was still a mirror slave.
        if displays.contains(where: { $0.state != .active }) {
            forceRecovery(preservePreferences: true)
        }
    }

    deinit {
        CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, nil)
        safetyTimer?.invalidate()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        lockObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
    }
    
    private func displayUUID(_ id: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }

    func fetchDisplays() {
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 128)
        guard CGGetOnlineDisplayList(128, &ids, &count) == .success else { return }
        let screens = NSScreen.screens
        let live = ids.prefix(Int(count)).map { id in
            DisplaySnapshot(id: id, uuid: displayUUID(id),
                name: screens.first(where: { $0.displayID == id })?.localizedName
                    ?? (CGDisplayIsBuiltin(id) != 0 ? "Built-in Display" : "Display \(id)"),
                isBuiltIn: CGDisplayIsBuiltin(id) != 0, isPrimary: CGMainDisplayID() == id,
                active: CGDisplayIsActive(id) != 0, mirrorSource: CGDisplayMirrorsDisplay(id))
        }
        preferencePolicy.observe(onlineUUIDs: Set(live.compactMap(\.uuid)))
        // A retry must never darken a new device that inherited a numeric ID.
        let lostBlackout = blackoutIDs.contains { id in
            guard let old = displays.first(where: { $0.id == id }), let uuid = old.uuid,
                  let current = live.first(where: { $0.id == id }) else { return true }
            return uuid != current.uuid || current.mirrorSource == 0
        }
        if lostBlackout {
            gammaService.restoreAll()
            blackoutIDs.removeAll()
        }
        displays = DisplayReconciler.reconcile(
            previous: displays, live: live, blackouts: blackoutIDs,
            managedOffUUIDs: Set(preferences.entries.map(\.targetUUID))
        )
        recoveryIDs.formIntersection(Set(displays.map(\.id)))
        for display in displays where recoveryIDs.contains(display.id) && display.state == .unavailable {
            if recovering && !recoveryDeadline.expired(now: ProcessInfo.processInfo.systemUptime) {
                display.state = .pending
            }
        }
        sortDisplays()
        persistDisplays()
        if displays.allSatisfy({ $0.state == .active }) { try? arrengementCache.cache() }
        if lostBlackout && !recovering { forceRecovery(preservePreferences: true) }
    }

    func disconnectDisplay(display: DisplayInfo, remember: Bool = true) throws(DisplayError) {
        try prepareToHide(display)
        let supports = visibleUUIDs(excluding: display.id)
        var succeeded = false
        defer { if !succeeded { forceRecovery(preservePreferences: true) } }
        display.state = .pending
        display.isManagedDisabled = true
        guard stateStore.save(displays) else {
            display.state = .active
            display.isManagedDisabled = false
            throw DisplayError(msg: "Cannot save recovery state; the display will remain enabled.")
        }
        var cid: CGDisplayConfigRef?
        let beginStatus = CGBeginDisplayConfiguration(&cid)
        
        guard beginStatus == .success, let config = cid else {
            throw DisplayError(msg: "Failed to begin configuring '\(display.name)'.")
        }
        
        let status = CGSConfigureDisplayEnabled(config, display.id, false)
        guard status == 0 else {
            CGCancelDisplayConfiguration(config)
            throw DisplayError(msg: "Failed to disconnect '\(display.name)'.")
        }
        
        let completeStatus = CGCompleteDisplayConfiguration(config, .forAppOnly)
        guard completeStatus == .success else {
            throw DisplayError(msg: "Failed to finish configuring '\(display.name)'.")
        }
        
        display.state = .disconnected
        if remember { try rememberOff(display, mode: .disconnect, supports: supports) }
        succeeded = true
        unRegisterMirrors(display: display)
        persistDisplays()
    }

    
    func disableDisplay(display: DisplayInfo, remember: Bool = true) throws(DisplayError) {
        try prepareToHide(display)
        let supports = visibleUUIDs(excluding: display.id)
        display.state = .pending
        display.isManagedDisabled = true
        guard stateStore.save(displays) else {
            display.state = .active
            display.isManagedDisabled = false
            throw DisplayError(msg: "Cannot save recovery state; the display will remain enabled.")
        }
        
        
        do {
            try mirrorDisplay(display)
            blackoutIDs.insert(display.id)
            try gammaService.setZeroGamma(for: display)
            if remember { try rememberOff(display, mode: .blackout, supports: supports) }
        } catch {
            forceRecovery(preservePreferences: true)
            throw DisplayError(msg: "Failed to apply a mirror-based disable to '\(display.name)'.")
        }
        unRegisterMirrors(display: display)
        persistDisplays()
    }
    
    func turnOnDisplay(display: DisplayInfo) throws(DisplayError) {
        // An explicit enable overrides the saved off preference for this device.
        if !preferences.replace(preferences.entries.filter { $0.targetUUID != display.uuid }) {
            automaticRestoreEnabled = false
        }
        forceRecovery(preservePreferences: true)
    }

    func resetAllDisplays() { forceRecovery() }

    /// Nuclear recovery: asks the user for admin credentials, then restarts
    /// WindowServer via launchctl. This forces macOS to re-enumerate all
    /// physically connected displays. Use when a display has been soft-
    /// disconnected and no longer appears in CGGetOnlineDisplayList.
    /// Completion: (success, errorMessage?)
    func restartWindowServer(completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            do shell script "launchctl kickstart -k system/com.apple.WindowServer" with administrator privileges
            """
            var errorInfo: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(&errorInfo)
            DispatchQueue.main.async {
                if let err = errorInfo, let msg = err[NSAppleScript.errorMessage] as? String {
                    completion(false, msg)
                } else {
                    completion(true, nil)
                }
            }
        }
    }

    /// Aggressive recovery: re-enables every online display ID (including
    /// ones the app no longer tracks in memory) and restores system display
    /// configuration. Use when a display was disabled but is no longer
    /// visible in the UI to be toggled back manually.
    func forceRecovery(preservePreferences: Bool = false) {
        preferencePolicy.suspend()
        if !preservePreferences {
            automaticRestoreEnabled = false
            _ = preferences.replace([])
        }
        // Do not reset the deadline on repeated hotkeys, lock events or topology callbacks.
        if recovering { attemptRecovery(); return }
        recoveryIDs = Set(displays.filter { $0.state != .active }.map(\.id))
        recovering = true
        recoveryDeadline.begin(now: ProcessInfo.processInfo.systemUptime)
        blackoutIDs.removeAll()
        gammaService.restoreAll()
        // Healthy displays need no configuration transaction and no permanent-layout reset.
        lastRecoveryAttempt = .distantPast
        attemptRecovery()
    }

    func unRegisterMirrors(display: DisplayInfo) {
        for mirror in display.mirroredTo {
            mirror.state = .active
        }
    }

    private func sortDisplays() {
        displays.sort {
            if $0.isPrimary {
                return true
            }
            if $1.isPrimary {
                return false
            }
            return $0.id < $1.id
        }
    }

    private func persistDisplays() {
        stateStore.save(displays)
    }
    
}

// MARK: - Mirroring Extention

extension DisplaysViewModel {
    fileprivate func mirrorDisplay(_ display: DisplayInfo) throws {
        let targetDisplayID = display.id
        
        guard let alternateDisplay = selectAlternateDisplay(excluding: targetDisplayID) else {
            throw DisplayError(msg: "No suitable alternate display found for mirroring.")
        }
        
        var configRef: CGDisplayConfigRef?
        let beginConfigError = CGBeginDisplayConfiguration(&configRef)
        guard beginConfigError == .success, let config = configRef else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(beginConfigError.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to begin display configuration."
            ])
        }
        
        let mirrorError = CGConfigureDisplayMirrorOfDisplay(config, targetDisplayID, alternateDisplay.id)
        guard mirrorError == .success else {
            CGCancelDisplayConfiguration(config)
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(mirrorError.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to mirror display \(alternateDisplay.name) to display \(display.name)."
            ])
        }
        
        let completeConfigError = CGCompleteDisplayConfiguration(config, .forAppOnly)
        guard completeConfigError == .success else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(completeConfigError.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to complete display configuration."
            ])
        }
        
        alternateDisplay.mirroredTo.append(display)
        display.mirrorSource = alternateDisplay
        print("Successfully mirrored display \(display.name) to \(alternateDisplay.name).")
    }
    
    private func selectAlternateDisplay(excluding currentDisplayID: CGDirectDisplayID) -> DisplayInfo? {
        let visible = visibleDisplayIDs(excluding: currentDisplayID)
        return displays.first { visible.contains($0.id) }
    }
}

// MARK: - NScreen Extentrion

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as! CGDirectDisplayID
    }
}

// MARK: - Automatic recovery
extension DisplaysViewModel {
    private func visibleDisplayIDs(excluding id: CGDirectDisplayID? = nil) -> Set<CGDirectDisplayID> {
        Set(displays.filter {
            $0.id != id && $0.state == .active && CGDisplayIsActive($0.id) != 0
                && CGDisplayIsOnline($0.id) != 0 && CGDisplayIsAsleep($0.id) == 0
                && CGDisplayMirrorsDisplay($0.id) == kCGNullDirectDisplay
        }.map(\.id))
    }

    private func prepareToHide(_ display: DisplayInfo) throws(DisplayError) {
        guard !recovering, display.state == .active,
              let uuid = display.uuid, uuid == displayUUID(display.id),
              displays.contains(where: { $0 === display }),
              CGDisplayIsOnline(display.id) != 0, CGDisplayIsActive(display.id) != 0 else {
            throw DisplayError(msg: "Display is unavailable or recovery is still in progress.")
        }
        guard display.mirroredTo.isEmpty else {
            throw DisplayError(msg: "Enable the mirrored display before hiding its source.")
        }
        let alternatives = visibleDisplayIDs(excluding: display.id)
        guard !alternatives.isEmpty else {
            throw DisplayError(msg: "Keep at least one awake, visible display available.")
        }
        anchors = alternatives
    }

    private func startSafetyMonitoring() {
        let callbackStatus = CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, nil)
        if callbackStatus != .success { print("Display callback unavailable: \(callbackStatus)") }
        observers.append(NotificationCenter.default.addObserver(
            forName: displayTopologyChanged, object: nil, queue: .main
        ) { [weak self] event in
            guard let self else { return }
            if event.userInfo?["removed"] as? Bool == true,
               let id = event.userInfo?["id"] as? CGDirectDisplayID,
               self.anchors.contains(id), !self.recovering,
               self.displays.contains(where: { $0.state != .active }) {
                self.forceRecovery(preservePreferences: true)
            } else {
                self.checkSafety()
            }
            self.fetchDisplays()
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.checkSafety()
            self?.fetchDisplays()
        })
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification,
                     NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidResignActiveNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in
                guard let self else { return }
                if name == NSWorkspace.willSleepNotification { self.systemSleeping = true }
                if name == NSWorkspace.didWakeNotification || name == NSWorkspace.screensDidWakeNotification {
                    self.systemSleeping = false
                }
                if name == NSWorkspace.sessionDidResignActiveNotification { self.sessionInactive = true }
                if name == NSWorkspace.sessionDidBecomeActiveNotification { self.sessionInactive = false }
                self.preferencePolicy.suspend()
                if self.displays.contains(where: { $0.state != .active }) { self.forceRecovery(preservePreferences: true) }
            })
        }
        // These lock notifications are best-effort, undocumented macOS events.
        // Keep topology, wake and watchdog recovery independent of their delivery.
        for name in ["com.apple.screenIsLocked", "com.apple.screenIsUnlocked"] {
            lockObservers.append(DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.sessionLocked = name == "com.apple.screenIsLocked"
                self.preferencePolicy.suspend()
                if self.displays.contains(where: { $0.state != .active }) { self.forceRecovery(preservePreferences: true) }
            })
        }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.checkSafety() }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        safetyTimer = timer
    }

    private func checkSafety() {
        if recovering { attemptRecovery(); return }
        fetchDisplays()
        if visibleDisplayIDs().isEmpty && displays.contains(where: { $0.state == .unavailable })
            && Date().timeIntervalSince(lastRecoveryAttempt) >= 15 {
            forceRecovery(preservePreferences: true)
            return
        }
        let hidden = displays.contains { $0.state == .mirrored || $0.state == .disconnected || $0.state == .pending }
        if hidden {
            let visible = visibleDisplayIDs()
            if DisplaySafetyPolicy.needsRecovery(visible: visible, anchors: anchors) {
                forceRecovery(preservePreferences: true)
                return
            }
        }
        restorePreferredDisplaysIfSafe()
    }

    private func attemptRecovery() {
        guard !attemptingRecovery, Date().timeIntervalSince(lastRecoveryAttempt) >= 1 else { return }
        attemptingRecovery = true
        defer { attemptingRecovery = false }
        lastRecoveryAttempt = Date()
        gammaService.restoreAll()
        fetchDisplays()
        for display in displays where recoveryIDs.contains(display.id) {
            let id = display.id
            let online = CGDisplayIsOnline(id) != 0
            let active = CGDisplayIsActive(id) != 0
            let mirrorSource = CGDisplayMirrorsDisplay(id)
            let action = DisplayRecoveryPlanner.action(
                online: online, active: active, mirrorSource: mirrorSource
            )
            // Observation comes first: a reattached monitor is often already healthy.
            if action == .none {
                recoveryIDs.remove(id)
                display.state = .active
                display.isManagedDisabled = false
                display.statusMessage = nil
                continue
            }
            if recoveryDeadline.expired(now: ProcessInfo.processInfo.systemUptime) { continue }
            display.state = .pending
            var ref: CGDisplayConfigRef?
            let begin = CGBeginDisplayConfiguration(&ref)
            guard begin == .success, let config = ref else {
                display.statusMessage = "Recovery failed (begin: \(begin.rawValue)). Click Retry."
                continue
            }
            let configureStatus: Int
            switch action {
            case .enable:
                configureStatus = CGSConfigureDisplayEnabled(config, id, true)
            case .unmirror:
                configureStatus = Int(CGConfigureDisplayMirrorOfDisplay(
                    config, id, kCGNullDirectDisplay
                ).rawValue)
            case .none:
                configureStatus = 0
            }
            guard configureStatus == 0 else {
                CGCancelDisplayConfiguration(config)
                display.statusMessage = "Recovery failed (\(action): \(configureStatus)). Click Retry."
                continue
            }
            let completed = CGCompleteDisplayConfiguration(config, .forAppOnly)
            if completed != .success {
                display.statusMessage = "macOS could not restore this display (error \(completed.rawValue)). Click Retry."
            } else {
                // Keep pending until the next inventory pass confirms the result.
                display.statusMessage = action == .enable
                    ? "Enabling display…" : "Leaving mirror mode…"
            }
        }
        gammaService.restoreAll()
        fetchDisplays()
        recoveryIDs = recoveryIDs.filter { id in
            !(CGDisplayIsOnline(id) != 0 && CGDisplayIsActive(id) != 0 && CGDisplayMirrorsDisplay(id) == 0)
        }
        if recoveryIDs.isEmpty || recoveryDeadline.expired(now: ProcessInfo.processInfo.systemUptime) {
            for display in displays where recoveryIDs.contains(display.id) {
                display.state = .unavailable
                if display.statusMessage == nil { display.statusMessage = "Display unavailable. Reconnect it or click Retry." }
            }
            recovering = false
            recoveryDeadline.finish()
            recoveryIDs.removeAll()
            anchors.removeAll()
        }
        persistDisplays()
    }
}

// MARK: - Remembered user configuration
extension DisplaysViewModel {
    func prefersOff(_ display: DisplayInfo) -> Bool {
        preferences.entries.contains { $0.targetUUID == display.uuid }
    }

    private func onlineUUIDs() -> Set<String> {
        Set(displays.filter { CGDisplayIsOnline($0.id) != 0 }.compactMap(\.uuid))
    }

    private func visibleUUIDs(excluding id: CGDirectDisplayID? = nil) -> Set<String> {
        let visible = visibleDisplayIDs(excluding: id)
        return Set(displays.filter { visible.contains($0.id) }.compactMap(\.uuid))
    }

    private func rememberOff(_ display: DisplayInfo, mode: DisplayOffPreference.Mode,
                             supports: Set<String>) throws(DisplayError) {
        guard let uuid = display.uuid, !supports.isEmpty else {
            throw DisplayError(msg: "Cannot identify a safe display configuration to remember.")
        }
        var entries = preferences.entries.filter { $0.targetUUID != uuid }
        entries.append(DisplayOffPreference(targetUUID: uuid, mode: mode, supportingUUIDs: supports))
        guard preferences.replace(entries) else {
            throw DisplayError(msg: "Cannot save the preferred display configuration.")
        }
        automaticRestoreEnabled = true
        preferencePolicy.resetFailure(uuid)
        preferencePolicy.suspend()
    }

    private func restorePreferredDisplaysIfSafe() {
        let online = onlineUUIDs()
        guard let entry = preferencePolicy.candidate(preferences: preferences.entries,
            activeUUIDs: visibleUUIDs(), onlineUUIDs: online,
            allowed: automaticRestoreEnabled && !recovering && !systemSleeping && !sessionLocked && !sessionInactive,
            now: ProcessInfo.processInfo.systemUptime),
            let display = displays.first(where: { $0.uuid == entry.targetUUID }) else { return }
        // The normal disable path rechecks hardware identity and last-visible-display safety.
        do {
            switch entry.mode {
            case .blackout: try disableDisplay(display: display, remember: false)
            case .disconnect: try disconnectDisplay(display: display, remember: false)
            }
            preferencePolicy.suspend()
        } catch {
            preferencePolicy.failed(entry.targetUUID, onlineUUIDs: online)
            display.statusMessage = "Could not restore saved configuration. Toggle this display to retry."
            print("Saved display configuration failed: \(error)")
        }
    }
}
