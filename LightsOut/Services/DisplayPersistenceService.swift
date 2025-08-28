//
//  DisplayPersistenceService.swift
//  LightsOut
//
//  Persistent storage for disconnected displays to prevent data loss
//

import CoreGraphics
import Foundation

struct DisplayStateData: Codable {
    let id: UInt32  // CGDirectDisplayID as UInt32 for Codable
    let name: String
    let state: String  // DisplayState as string
    let isPrimary: Bool
    let isBuiltIn: Bool
    let lastSeen: Date
    
    init(from display: DisplayInfo) {
        self.id = display.id
        self.name = display.name
        self.state = display.state.rawValue
        self.isPrimary = display.isPrimary
        self.isBuiltIn = BuiltInDisplayGuard.shared.isBuiltInDisplay(display.id)
        self.lastSeen = Date()
    }
    
    func toDisplayInfo() -> DisplayInfo {
        let displayState: DisplayState = DisplayState.fromString(self.state)
        return DisplayInfo(
            id: CGDirectDisplayID(self.id),
            name: self.name,
            state: displayState,
            isPrimary: self.isPrimary
        )
    }
}

extension DisplayState {
    var rawValue: String {
        switch self {
        case .mirrored: return "mirrored"
        case .disconnected: return "disconnected"  
        case .pending: return "pending"
        case .active: return "active"
        }
    }
    
    static func fromString(_ value: String) -> DisplayState {
        switch value {
        case "mirrored": return .mirrored
        case "disconnected": return .disconnected
        case "pending": return .pending
        default: return .active
        }
    }
}

class DisplayPersistenceService {
    static let shared = DisplayPersistenceService()
    private let userDefaults = UserDefaults.standard
    private let persistenceKey = "LightsOut_DisplayStates_v2"
    private let maxAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    
    private init() {}
    
    /// Save current display states to persistent storage
    func saveDisplayStates(_ displays: [DisplayInfo]) {
        let stateData = displays.map { DisplayStateData(from: $0) }
        
        do {
            let encoded = try JSONEncoder().encode(stateData)
            userDefaults.set(encoded, forKey: persistenceKey)
            userDefaults.synchronize()
            
            print("💾 Saved \(stateData.count) display states to persistence")
            
            // Log details for debugging
            for state in stateData {
                print("   - \(state.name) (ID: \(state.id), State: \(state.state), Built-in: \(state.isBuiltIn))")
            }
        } catch {
            print("❌ Failed to save display states: \(error)")
        }
    }
    
    /// Load previously saved display states
    func loadDisplayStates() -> [DisplayInfo] {
        guard let data = userDefaults.data(forKey: persistenceKey) else {
            print("📂 No persistent display states found")
            return []
        }
        
        do {
            let stateData = try JSONDecoder().decode([DisplayStateData].self, from: data)
            
            // Filter out old entries to prevent stale data
            let cutoffDate = Date().addingTimeInterval(-maxAge)
            let recentStates = stateData.filter { $0.lastSeen > cutoffDate }
            
            let displays = recentStates.map { $0.toDisplayInfo() }
            
            print("📂 Loaded \(displays.count) persistent display states (filtered \(stateData.count - recentStates.count) old entries)")
            
            // Log details for debugging  
            for display in displays {
                print("   - \(display.name) (ID: \(display.id), State: \(display.state))")
            }
            
            return displays
        } catch {
            print("❌ Failed to load display states: \(error)")
            // Clear corrupted data
            userDefaults.removeObject(forKey: persistenceKey)
            return []
        }
    }
    
    /// Get only disconnected displays from persistence
    func getDisconnectedDisplays() -> [DisplayInfo] {
        let allStates = loadDisplayStates()
        return allStates.filter { $0.state.isOff() }
    }
    
    /// Remove a display from persistent storage
    func removeDisplayFromPersistence(_ displayID: CGDirectDisplayID) {
        let currentStates = loadDisplayStates()
        let filteredStates = currentStates.filter { $0.id != displayID }
        saveDisplayStates(filteredStates)
        
        print("🗑️ Removed display ID \(displayID) from persistence")
    }
    
    /// Clear all persistent display data (for testing/reset)
    func clearAllPersistentData() {
        userDefaults.removeObject(forKey: persistenceKey)
        userDefaults.synchronize()
        print("🧹 Cleared all persistent display data")
    }
    
    /// Get statistics about persistent data
    func getPersistenceStats() -> (total: Int, disconnected: Int, builtin: Int) {
        let states = loadDisplayStates()
        let disconnectedCount = states.filter { $0.state.isOff() }.count
        let builtinCount = states.filter { BuiltInDisplayGuard.shared.isBuiltInDisplay($0.id) }.count
        
        return (total: states.count, disconnected: disconnectedCount, builtin: builtinCount)
    }
}