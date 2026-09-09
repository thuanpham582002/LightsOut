import Foundation

struct DisplayOffPreference: Codable, Equatable {
    enum Mode: String, Codable { case blackout, disconnect }
    let targetUUID: String
    let mode: Mode
    let supportingUUIDs: Set<String>
}

enum DisplayPreferenceMigration {
    static func trueDisconnectForBuiltIn(
        _ entries: [DisplayOffPreference], builtInUUIDs: Set<String>
    ) -> [DisplayOffPreference] {
        entries.map { entry in
            guard builtInUUIDs.contains(entry.targetUUID), entry.mode == .blackout else {
                return entry
            }
            return DisplayOffPreference(targetUUID: entry.targetUUID, mode: .disconnect,
                                        supportingUUIDs: entry.supportingUUIDs)
        }
    }
}

/// User intent is independent of the observed/recovery journal.
final class DisplayPreferenceStore {
    private let url: URL
    private(set) var entries: [DisplayOffPreference]

    init(url: URL = FileManager.default.urls(for: .applicationSupportDirectory,
         in: .userDomainMask).first!.appendingPathComponent("LightsOut/display-preferences.json")) {
        self.url = url
        entries = (try? JSONDecoder().decode([DisplayOffPreference].self,
                    from: Data(contentsOf: url))) ?? []
    }

    @discardableResult
    func replace(_ entries: [DisplayOffPreference]) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: url, options: .atomic)
            self.entries = entries
            return true
        } catch {
            print("Cannot save display preferences: \(error)")
            return false
        }
    }
}

/// Debounce eligibility, not merely a plug event; missed events are covered by polling.
struct DisplayPreferenceRestorePolicy {
    private var eligibleSince: [String: TimeInterval] = [:]
    private var failedTopology: [String: Set<String>] = [:]
    private var lastTopology: Set<String>?

    mutating func observe(onlineUUIDs: Set<String>) {
        if lastTopology != onlineUUIDs {
            eligibleSince.removeAll()
            failedTopology.removeAll()
            lastTopology = onlineUUIDs
        }
    }

    mutating func suspend() { eligibleSince.removeAll() }

    mutating func failed(_ uuid: String, onlineUUIDs: Set<String>) {
        failedTopology[uuid] = onlineUUIDs
        eligibleSince.removeValue(forKey: uuid)
    }

    mutating func resetFailure(_ uuid: String) { failedTopology.removeValue(forKey: uuid) }

    mutating func candidate(preferences: [DisplayOffPreference], activeUUIDs: Set<String>,
                            onlineUUIDs: Set<String>, allowed: Bool,
                            now: TimeInterval) -> DisplayOffPreference? {
        observe(onlineUUIDs: onlineUUIDs)
        guard allowed else { suspend(); return nil }
        let hiddenTargets = Set(preferences.map(\.targetUUID))
        let safeSources = activeUUIDs.subtracting(hiddenTargets)
        let eligible = preferences.filter {
            activeUUIDs.contains($0.targetUUID)
                && !$0.supportingUUIDs.intersection(safeSources).isEmpty
                && failedTopology[$0.targetUUID] != onlineUUIDs
        }
        let ids = Set(eligible.map(\.targetUUID))
        eligibleSince = eligibleSince.filter { ids.contains($0.key) }
        for entry in eligible {
            if eligibleSince[entry.targetUUID] == nil { eligibleSince[entry.targetUUID] = now }
        }
        return eligible.first { now - (eligibleSince[$0.targetUUID] ?? now) >= 3 }
    }
}
