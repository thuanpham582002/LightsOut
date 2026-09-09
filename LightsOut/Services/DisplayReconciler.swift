import Foundation

struct DisplaySnapshot {
    let id: UInt32
    let uuid: String?
    let name: String
    let isBuiltIn: Bool
    let isPrimary: Bool
    let active: Bool
    let mirrorSource: UInt32
}

enum DisplayRecoveryAction: Equatable {
    case none
    case enable
    case unmirror
}

enum DisplayRecoveryPlanner {
    static func action(online: Bool, active: Bool, mirrorSource: UInt32) -> DisplayRecoveryAction {
        if online && active && mirrorSource == 0 { return .none }
        // Enabling an offline panel and unmirroring it in the same transaction
        // can make WindowServer reject the entire configuration with error 1001.
        if !online || !active { return .enable }
        return .unmirror
    }
}

/// State on disk is a recovery hint, never authority over a live display.
enum DisplayReconciler {
    static func reconcile(previous: [DisplayInfo], live: [DisplaySnapshot],
                          blackouts: Set<UInt32>,
                          managedOffUUIDs: Set<String> = []) -> [DisplayInfo] {
        let liveIDs = Set(live.map(\.id))
        let liveUUIDs = Set(live.compactMap(\.uuid))
        var result = live.map { snapshot -> DisplayInfo in
            let old = previous.first { $0.id == snapshot.id && $0.uuid == snapshot.uuid }
            let display = old ?? DisplayInfo(id: snapshot.id, name: snapshot.name,
                state: .active, isPrimary: snapshot.isPrimary, uuid: snapshot.uuid,
                isBuiltIn: snapshot.isBuiltIn)
            display.name = snapshot.name
            display.uuid = snapshot.uuid
            display.isBuiltIn = snapshot.isBuiltIn
            display.isPrimary = snapshot.isPrimary
            let state: DisplayState
            let managedMirror = snapshot.mirrorSource != 0
                && snapshot.uuid.map(managedOffUUIDs.contains) == true
            if old != nil && (blackouts.contains(snapshot.id) || managedMirror) {
                state = .mirrored
            } else if snapshot.active || snapshot.mirrorSource != 0 {
                state = .active
            } else {
                state = .unavailable
            }
            if display.state != state { display.state = state }
            display.isManagedDisabled = state == .mirrored
            if state == .active {
                display.statusMessage = nil
                if blackouts.isEmpty {
                    display.mirrorSource = nil
                    display.mirroredTo.removeAll()
                }
            }
            return display
        }
        // Retain built-in recovery evidence and deliberately disabled displays.
        // A stale pending row for a removed external monitor is not a device.
        for old in previous where !liveIDs.contains(old.id) {
            if let uuid = old.uuid, liveUUIDs.contains(uuid) { continue }
            guard old.isBuiltIn || old.isManagedDisabled else { continue }
            old.isPrimary = false
            if old.state != .disconnected { old.state = .unavailable }
            result.append(old)
        }
        return result
    }
}

/// Repeated notifications cannot extend a recovery attempt indefinitely.
struct RecoveryDeadline {
    private(set) var started: TimeInterval?
    mutating func begin(now: TimeInterval) { if started == nil { started = now } }
    func expired(now: TimeInterval) -> Bool { started.map { now - $0 >= 8 } ?? false }
    mutating func finish() { started = nil }
}
