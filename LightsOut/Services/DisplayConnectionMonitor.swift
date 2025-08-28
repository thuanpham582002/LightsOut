//
//  DisplayConnectionMonitor.swift
//  LightsOut
//
//  Monitors display connection events (hot-plug/unplug) to maintain accurate state
//

import CoreGraphics
import Foundation

protocol DisplayConnectionDelegate: AnyObject {
    func displayConnectionChanged()
    func displayConnected(_ displayID: CGDirectDisplayID)
    func displayDisconnected(_ displayID: CGDirectDisplayID)
}

class DisplayConnectionMonitor {
    static let shared = DisplayConnectionMonitor()
    
    weak var delegate: DisplayConnectionDelegate?
    private var isMonitoring = false
    private var previousDisplayIDs: Set<CGDirectDisplayID> = Set()
    
    private init() {}
    
    /// Start monitoring display connection changes
    func startMonitoring() {
        guard !isMonitoring else {
            print("⚠️ Display connection monitoring already active")
            return
        }
        
        print("🔌 Starting display connection monitoring...")
        
        // Store initial display state
        updateDisplayIDCache()
        
        // Register for display reconfiguration callbacks
        let result = CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, 
                                                             Unmanaged.passUnretained(self).toOpaque())
        
        if result == .success {
            isMonitoring = true
            print("✅ Display connection monitoring started successfully")
        } else {
            print("❌ Failed to start display connection monitoring: \(result)")
        }
    }
    
    /// Stop monitoring display connection changes
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        print("🔌 Stopping display connection monitoring...")
        
        let result = CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, 
                                                           Unmanaged.passUnretained(self).toOpaque())
        
        if result == .success {
            isMonitoring = false
            print("✅ Display connection monitoring stopped successfully")
        } else {
            print("❌ Failed to stop display connection monitoring: \(result)")
        }
    }
    
    /// Update our cache of current display IDs
    private func updateDisplayIDCache() {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &activeDisplays, &displayCount)
        
        previousDisplayIDs = Set(activeDisplays)
        print("📱 Updated display cache: \(previousDisplayIDs.count) displays")
    }
    
    /// Handle display configuration changes
    private func handleDisplayReconfiguration(displayID: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
        print("🔄 Display reconfiguration: Display \(displayID), Flags: \(flags)")
        
        // Get current display state
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &activeDisplays, &displayCount)
        let currentDisplayIDs = Set(activeDisplays)
        
        // Detect added displays
        let addedDisplays = currentDisplayIDs.subtracting(previousDisplayIDs)
        for addedDisplayID in addedDisplays {
            print("➕ Display connected: \(addedDisplayID)")
            handleDisplayConnected(addedDisplayID)
        }
        
        // Detect removed displays  
        let removedDisplays = previousDisplayIDs.subtracting(currentDisplayIDs)
        for removedDisplayID in removedDisplays {
            print("➖ Display disconnected: \(removedDisplayID)")
            handleDisplayDisconnected(removedDisplayID)
        }
        
        // Handle other configuration changes
        if flags.contains(.setModeFlag) {
            print("🔧 Display mode changed: \(displayID)")
        }
        
        if flags.contains(.setOriginFlag) {
            print("📍 Display position changed: \(displayID)")
        }
        
        if flags.contains(.enabledFlag) || flags.contains(.disabledFlag) {
            print("🔘 Display enabled/disabled state changed: \(displayID)")
        }
        
        // Update cache for next comparison
        previousDisplayIDs = currentDisplayIDs
        
        // Notify delegate of changes
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.displayConnectionChanged()
        }
    }
    
    /// Handle display connection event
    private func handleDisplayConnected(_ displayID: CGDirectDisplayID) {
        // 🛡️ BUILT-IN DISPLAY PROTECTION: Check if this is built-in display coming back online
        if BuiltInDisplayGuard.shared.isBuiltInDisplay(displayID) {
            print("🏠 Built-in display reconnected: \(displayID)")
            
            // Ensure built-in display is never in disconnected state when it comes back
            BuiltInDisplayGuard.shared.ensureBuiltInDisplayActive()
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.displayConnected(displayID)
        }
    }
    
    /// Handle display disconnection event  
    private func handleDisplayDisconnected(_ displayID: CGDirectDisplayID) {
        // 🛡️ BUILT-IN DISPLAY PROTECTION: Critical alert if built-in display disappears
        if BuiltInDisplayGuard.shared.isBuiltInDisplay(displayID) {
            print("🚨 CRITICAL: Built-in display lost: \(displayID)")
            print("🚨 This should NEVER happen! System may be in unrecoverable state!")
            
            // This is emergency situation - built-in display hardware disconnected?
            // Only solution might be reboot
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.displayDisconnected(displayID)
        }
    }
    
    /// Get current monitoring status
    var monitoringStatus: (isMonitoring: Bool, displayCount: Int) {
        return (isMonitoring: isMonitoring, displayCount: previousDisplayIDs.count)
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - C Callback Function
/// C callback function for display reconfiguration events
private func displayReconfigurationCallback(
    display: CGDirectDisplayID,
    flags: CGDisplayChangeSummaryFlags,
    userInfo: UnsafeMutableRawPointer?
) {
    guard let userInfo = userInfo else { return }
    
    let monitor = Unmanaged<DisplayConnectionMonitor>.fromOpaque(userInfo).takeUnretained()
    monitor.handleDisplayReconfiguration(displayID: display, flags: flags)
}

// MARK: - CGDisplayChangeSummaryFlags Extensions
extension CGDisplayChangeSummaryFlags {
    var description: String {
        var descriptions: [String] = []
        
        if contains(.addFlag) { descriptions.append("ADD") }
        if contains(.removeFlag) { descriptions.append("REMOVE") }
        if contains(.enabledFlag) { descriptions.append("ENABLED") }
        if contains(.disabledFlag) { descriptions.append("DISABLED") }
        if contains(.setModeFlag) { descriptions.append("MODE_CHANGE") }
        if contains(.setOriginFlag) { descriptions.append("POSITION_CHANGE") }
        if contains(.desktopShapeChangedFlag) { descriptions.append("DESKTOP_SHAPE") }
        
        return descriptions.isEmpty ? "NONE" : descriptions.joined(separator: ", ")
    }
}