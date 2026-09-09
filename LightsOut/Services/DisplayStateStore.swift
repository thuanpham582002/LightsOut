//
//  DisplayStateStore.swift
//  BlackoutTest

import Foundation
import CoreGraphics

final class DisplayStateStore {
    private struct StoredDisplay: Codable {
        let id: CGDirectDisplayID
        let name: String
        let state: DisplayState
        let isPrimary: Bool
        let uuid: String?
        let isBuiltIn: Bool?
        let isManagedDisabled: Bool?
    }

    private let storageURL: URL
    private var lastSavedData: Data?

    init(storageURL: URL = DisplayStateStore.defaultStorageURL) {
        self.storageURL = storageURL
    }

    func load() -> [DisplayInfo] {
        guard let data = try? Data(contentsOf: storageURL),
              let storedDisplays = try? JSONDecoder().decode([StoredDisplay].self, from: data) else {
            return []
        }

        return storedDisplays.map {
            let display = DisplayInfo(id: $0.id, name: $0.name, state: $0.state, isPrimary: $0.isPrimary,
                                      uuid: $0.uuid, isBuiltIn: $0.isBuiltIn ?? false)
            display.isManagedDisabled = $0.isManagedDisabled ?? ($0.state == .disconnected)
            return display
        }
    }

    @discardableResult
    func save(_ displays: [DisplayInfo]) -> Bool {
        let storedDisplays = displays.map {
            StoredDisplay(id: $0.id, name: $0.name, state: $0.state, isPrimary: $0.isPrimary,
                          uuid: $0.uuid, isBuiltIn: $0.isBuiltIn, isManagedDisabled: $0.isManagedDisabled)
        }

        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(storedDisplays)
            if data == lastSavedData { return true }
            try data.write(to: storageURL, options: .atomic)
            lastSavedData = data
            return true
        } catch {
            print("Failed to persist display state: \(error)")
            return false
        }
    }

    private static var defaultStorageURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LightsOut", isDirectory: true)
        return directory.appendingPathComponent("display-state.json")
    }
}
