import Foundation

@main
struct SafetyRegression {
    static func main() throws {
        try testPreferredConfiguration()
        // Regression: cached pending/disconnected cannot overrule healthy hardware.
        let oldPanel = DisplayInfo(id: 1, name: "Old panel", state: .disconnected,
                                   isPrimary: false, uuid: "panel", isBuiltIn: true)
        let stuck = DisplayInfo(id: 2, name: "Display 2", state: .pending,
                                isPrimary: false, uuid: "monitor")
        let panel = DisplaySnapshot(id: 1, uuid: "panel", name: "Built-in Retina Display",
            isBuiltIn: true, isPrimary: false, active: true, mirrorSource: 0)
        let monitor = DisplaySnapshot(id: 2, uuid: "monitor", name: "New monitor",
            isBuiltIn: false, isPrimary: true, active: true, mirrorSource: 0)
        let reconciled = DisplayReconciler.reconcile(previous: [oldPanel, stuck],
            live: [panel, monitor], blackouts: [])
        assert(reconciled.allSatisfy { $0.state == .active })
        assert(reconciled[1].name == "New monitor" && reconciled[1].isPrimary)

        // Numeric ID reuse must not transfer blackout or error state to another device.
        let replacement = DisplaySnapshot(id: 2, uuid: "replacement", name: "Replacement",
            isBuiltIn: false, isPrimary: true, active: true, mirrorSource: 0)
        stuck.state = .mirrored
        let swapped = DisplayReconciler.reconcile(previous: [stuck], live: [replacement], blackouts: [2])
        assert(swapped[0] !== stuck && swapped[0].state == .active && swapped[0].uuid == "replacement")
        let owned = DisplayReconciler.reconcile(previous: [stuck], live: [monitor], blackouts: [2])
        assert(owned[0].state == .mirrored, "A live, app-owned blackout was lost")
        // Regression: after restart the in-memory blackout set is empty, but
        // durable preference ownership must keep a live mirror recoverable.
        let mirroredLive = DisplaySnapshot(id: 1, uuid: "panel", name: "Panel",
            isBuiltIn: true, isPrimary: false, active: false, mirrorSource: 2)
        let afterRestart = DisplayReconciler.reconcile(
            previous: [oldPanel], live: [mirroredLive], blackouts: [],
            managedOffUUIDs: ["panel"]
        )
        assert(afterRestart[0].state == .mirrored && afterRestart[0].isManagedDisabled)
        let nativeMirror = DisplayReconciler.reconcile(
            previous: [], live: [mirroredLive], blackouts: [], managedOffUUIDs: []
        )
        assert(nativeMirror[0].state == .active,
               "LightsOut must not claim or recover a mirror it does not own")

        // A ghost external pending row disappears; missing built-in evidence remains retryable.
        stuck.state = .pending
        stuck.isManagedDisabled = false
        let missing = DisplayReconciler.reconcile(previous: [oldPanel, stuck], live: [], blackouts: [])
        assert(missing.count == 1 && missing[0].isBuiltIn && missing[0].state == .unavailable)
        let moved = DisplaySnapshot(id: 9, uuid: "panel", name: "Panel moved",
            isBuiltIn: true, isPrimary: true, active: true, mirrorSource: 0)
        let renumbered = DisplayReconciler.reconcile(previous: missing, live: [moved], blackouts: [])
        assert(renumbered.count == 1 && renumbered[0].id == 9 && renumbered[0].state == .active)

        var deadline = RecoveryDeadline()
        deadline.begin(now: 100)
        for t in 101...107 { deadline.begin(now: Double(t)) }
        assert(!deadline.expired(now: 107.9) && deadline.expired(now: 108))
        deadline.finish()
        deadline.begin(now: 120)
        assert(!deadline.expired(now: 120), "Manual Retry needs a fresh bounded attempt")

        // Exhaustively simulate dock/cable churn over five display IDs.
        var cases = 0
        for anchorMask in 1..<32 {
            let anchors = Set((0..<5).filter { anchorMask & (1 << $0) != 0 }.map(UInt32.init))
            for visibleMask in 0..<32 {
                let visible = Set((0..<5).filter { visibleMask & (1 << $0) != 0 }.map(UInt32.init))
                let lostAnchor = anchors.contains { !visible.contains($0) }
                assert(DisplaySafetyPolicy.needsRecovery(visible: visible, anchors: anchors) == lostAnchor)
                cases += 1
            }
        }
        assert(DisplaySafetyPolicy.needsRecovery(visible: [], anchors: []))
        assert(!DisplaySafetyPolicy.needsRecovery(visible: [2], anchors: [2]))
        assert(DisplaySafetyPolicy.needsRecovery(visible: [3], anchors: [2, 3]))

        // Exercise the real timer service with injected writes: never darken hardware in tests.
        var writes = 0
        var restores = 0
        var failures = 0
        var safe = true
        let service = GammaUpdateService(writeBlackout: { _ in writes += 1; return true },
                                         restoreColor: { restores += 1 })
        service.canBlackout = { _ in safe }
        service.onFailure = { failures += 1; service.restoreAll() }
        let display = DisplayInfo(id: 1, name: "Test built-in", state: .active, isPrimary: false)
        try service.setZeroGamma(for: display)
        assert(display.state == .mirrored && writes == 1)
        service.restoreAll()
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        assert(writes == 1 && restores == 1, "A cancelled timer re-darkened the panel")

        try service.setZeroGamma(for: display)
        safe = false // Last external monitor disappears before the next gamma retry.
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        assert(writes == 2 && failures == 1 && restores == 2)
        do {
            try service.setZeroGamma(for: display)
            assertionFailure("Blackout without a visible alternate was accepted")
        } catch { }
        assert(writes == 2)

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let stateURL = root.appendingPathComponent("state.json")
        let store = DisplayStateStore(storageURL: stateURL)
        display.state = .pending
        assert(store.save([display]))
        let reloaded = store.load()
        assert(reloaded.count == 1 && reloaded[0].id == 1 && reloaded[0].state == .pending)
        let legacyURL = root.appendingPathComponent("legacy.json")
        try Data("[{\"id\":2,\"name\":\"Old name\",\"state\":\"pending\",\"isPrimary\":false}]".utf8).write(to: legacyURL)
        let legacy = DisplayStateStore(storageURL: legacyURL).load()
        assert(legacy.count == 1 && legacy[0].uuid == nil)
        let migrated = DisplayReconciler.reconcile(previous: legacy, live: [monitor], blackouts: [])
        assert(migrated[0].state == .active && migrated[0].uuid == "monitor")
        // A write failure must be reportable before a display is disabled.
        let blocked = DisplayStateStore(storageURL: stateURL.appendingPathComponent("child.json"))
        assert(!blocked.save([display]))
        print("PASS: reconciliation, ID reuse, ghost rows, legacy migration, bounded recovery; \(cases) topology cases; gamma cancellation; journal/write failure")
    }

    private static func testPreferredConfiguration() throws {
        let entry = DisplayOffPreference(targetUUID: "builtin", mode: .blackout,
                                         supportingUUIDs: ["external"])
        let migrated = DisplayPreferenceMigration.trueDisconnectForBuiltIn(
            [entry], builtInUUIDs: ["builtin"]
        )
        assert(migrated[0].mode == .disconnect)
        let explicitExternalBlackout = DisplayOffPreference(
            targetUUID: "external", mode: .blackout, supportingUUIDs: ["builtin"]
        )
        assert(DisplayPreferenceMigration.trueDisconnectForBuiltIn(
            [explicitExternalBlackout], builtInUUIDs: ["builtin"]
        )[0].mode == .blackout)
        assert(DisplayRecoveryPlanner.action(online: true, active: true, mirrorSource: 0) == .none)
        assert(DisplayRecoveryPlanner.action(online: false, active: false, mirrorSource: 0) == .enable)
        assert(DisplayRecoveryPlanner.action(online: true, active: false, mirrorSource: 2) == .enable)
        assert(DisplayRecoveryPlanner.action(online: true, active: true, mirrorSource: 2) == .unmirror)
        var policy = DisplayPreferenceRestorePolicy()
        func candidate(_ now: Double, _ active: Set<String>, allowed: Bool = true) -> DisplayOffPreference? {
            policy.candidate(preferences: [entry], activeUUIDs: active, onlineUUIDs: active,
                             allowed: allowed, now: now)
        }
        assert(candidate(0, ["builtin"]) == nil)
        assert(candidate(10, ["builtin", "different-monitor"]) == nil)
        assert(candidate(20, ["builtin", "external"]) == nil)
        assert(candidate(22.9, ["builtin", "external"]) == nil)
        assert(candidate(23, ["builtin", "external"]) == entry)
        // A cable flap resets the complete stability interval.
        assert(candidate(24, ["builtin"]) == nil)
        assert(candidate(25, ["builtin", "external"]) == nil)
        assert(candidate(27.9, ["builtin", "external"]) == nil)
        assert(candidate(28, ["builtin", "external"]) == entry)
        // Lock/recovery pauses restoration; resume still waits three seconds.
        assert(candidate(30, ["builtin", "external"], allowed: false) == nil)
        assert(candidate(31, ["builtin", "external"]) == nil)
        assert(candidate(34, ["builtin", "external"]) == entry)
        policy.failed("builtin", onlineUUIDs: ["builtin", "external"])
        assert(candidate(60, ["builtin", "external"]) == nil)
        assert(candidate(61, ["builtin"]) == nil)
        assert(candidate(62, ["builtin", "external"]) == nil)
        assert(candidate(65, ["builtin", "external"]) == entry)
        // Cyclic preferences must never hide the final available screen.
        let other = DisplayOffPreference(targetUUID: "external", mode: .disconnect,
                                          supportingUUIDs: ["builtin"])
        assert(policy.candidate(preferences: [entry, other], activeUUIDs: ["builtin", "external"],
            onlineUUIDs: ["builtin", "external"], allowed: true, now: 100) == nil)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("preferences.json")
        let store = DisplayPreferenceStore(url: url)
        assert(store.replace([entry]))
        let observed = DisplayInfo(id: 1, name: "Built-in", state: .active, isPrimary: true)
        assert(DisplayStateStore(storageURL: directory.appendingPathComponent("state.json")).save([observed]))
        assert(DisplayPreferenceStore(url: url).entries == [entry], "Recovery overwrote user intent")
        assert(store.replace([]))
        assert(DisplayPreferenceStore(url: url).entries.isEmpty, "Manual enable/reset was not persisted")
        print("PASS: saved configuration; reconnect stability, cable flaps, lock, failure backoff and manual override")
    }
}
