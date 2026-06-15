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
    }

    private let storageURL: URL

    init(storageURL: URL = DisplayStateStore.defaultStorageURL) {
        self.storageURL = storageURL
    }

    func load() -> [DisplayInfo] {
        guard let data = try? Data(contentsOf: storageURL),
              let storedDisplays = try? JSONDecoder().decode([StoredDisplay].self, from: data) else {
            return []
        }

        return storedDisplays.map {
            DisplayInfo(id: $0.id, name: $0.name, state: $0.state, isPrimary: $0.isPrimary)
        }
    }

    func save(_ displays: [DisplayInfo]) {
        let storedDisplays = displays.map {
            StoredDisplay(id: $0.id, name: $0.name, state: $0.state, isPrimary: $0.isPrimary)
        }

        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(storedDisplays)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to persist display state: \(error)")
        }
    }

    private static var defaultStorageURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LightsOut", isDirectory: true)
        return directory.appendingPathComponent("display-state.json")
    }
}
