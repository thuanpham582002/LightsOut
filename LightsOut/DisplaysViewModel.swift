//
//  DisplaysViewModel.swift
//  BlackoutTest

import CoreGraphics
import SwiftUI

@_silgen_name("CGSConfigureDisplayEnabled")
func CGSConfigureDisplayEnabled(_ cid: CGDisplayConfigRef, _ display: UInt32, _ enabled: Bool) -> Int

class DisplaysViewModel: ObservableObject, DisplayConnectionDelegate, SleepWakeDelegate, EmergencyHotkeyDelegate {
    @Published var displays: [DisplayInfo] = []
    private var gammaService = GammaUpdateService()
    private var arrengementCache = DisplayArrangementCacheService()
    
    init() {
        fetchDisplays()
        setupMonitoringServices()
        setupRecoverySystem()
    }
    
    /// Setup recovery system integration
    private func setupRecoverySystem() {
        DisplayRecoverySystem.shared.displaysViewModel = self
    }
    
    /// Setup monitoring services (connection, sleep/wake, emergency hotkey)
    private func setupMonitoringServices() {
        // Setup display connection monitoring
        DisplayConnectionMonitor.shared.delegate = self
        DisplayConnectionMonitor.shared.startMonitoring()
        
        // Setup sleep/wake monitoring  
        SleepWakeManager.shared.delegate = self
        SleepWakeManager.shared.startMonitoring()
        
        // Setup emergency hotkey monitoring
        EmergencyHotkeyManager.shared.delegate = self
        EmergencyHotkeyManager.shared.startMonitoring()
    }
    
    func fetchDisplays() {
        print("🔄 Fetching displays with persistence support...")
        
        // 1️⃣ Get currently active displays from system with error handling
        let activeDisplaysResult = DisplayAPIWrapper.shared.getActiveDisplayList()
        let activeDisplays: [CGDirectDisplayID]
        
        switch activeDisplaysResult {
        case .success(let displays):
            activeDisplays = displays
        case .failure(let error):
            print("❌ DisplayAPI Error in fetchDisplays: \(error)")
            print("❌ Failed to get active display list, using empty list")
            activeDisplays = []
        }
        
        var new_displays: Set<DisplayInfo> = Set()
        let primaryDisplayID = CGMainDisplayID()
        
        // 2️⃣ Create DisplayInfo objects for all active displays
        new_displays = Set(activeDisplays.compactMap { displayID in
            var displayName = "Display \(displayID)"
            if let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
                displayName = screen.localizedName
            }
            return DisplayInfo(
                id: displayID,
                name: displayName,
                state: .active,
                isPrimary: displayID == primaryDisplayID
            )
        })
        
        print("📱 Found \(new_displays.count) active displays")
        
        // 3️⃣ ENHANCED: Load persistent disconnected displays 
        let persistentDisplays = DisplayPersistenceService.shared.getDisconnectedDisplays()
        print("💾 Found \(persistentDisplays.count) persistent disconnected displays")
        
        // 4️⃣ Merge persistent displays that are not currently active
        for persistentDisplay in persistentDisplays {
            // Only add if not already in active list
            if !new_displays.contains(where: { $0.id == persistentDisplay.id }) {
                persistentDisplay.isPrimary = false // Disconnected displays can't be primary
                new_displays.insert(persistentDisplay)
                print("🔗 Restored disconnected display: \(persistentDisplay.name) (ID: \(persistentDisplay.id))")
            }
        }
        
        // 5️⃣ LEGACY: Preserve displays from current memory (for backwards compatibility)
        for display in displays {
            if display.state.isOff() || display.state == .pending {
                display.isPrimary = false
                new_displays.insert(display)
                print("🔄 Preserved in-memory disconnected display: \(display.name)")
            }
        }
        
        displays = Array(new_displays)
        
        displays.sort {
            if $0.isPrimary {
                return true
            }
            if $1.isPrimary {
                return false
            }
            return $0.id < $1.id
        }
        
        try! arrengementCache.cache()
    }
    
    func disconnectDisplay(display: DisplayInfo) throws {
        // 🛡️ BUILT-IN DISPLAY PROTECTION
        let validation = BuiltInDisplayGuard.shared.validateDisplayOperation(display, operation: .disconnect)
        
        switch validation {
        case .blocked(let reason):
            throw DisplayError(msg: "🛑️ Built-in Display Protection: \(reason)")
        case .warning(let message):
            print("⚠️ Display Warning: \(message)")
            // Continue with operation but log warning
        case .allowed:
            break
        }
        
        display.state = .pending
        
        // 🔧 ENHANCED ERROR HANDLING: Use comprehensive API wrapper
        // Use direct API call without wrapper
        let result = DisplayAPIWrapper.shared.configureDisplayEnabled(nil, displayID: display.id, enabled: false)
        
        switch result {
        case .success:
            print("✅ Successfully disconnected \(display.name)")
        case .failure(let error):
            print("❌ DisplayAPI Error in disconnectDisplay(\(display.name)): \(error)")
            throw DisplayError(msg: "Failed to disconnect '\(display.name)': \(error.localizedDescription)")
        }
        
        display.state = .disconnected
        unRegisterMirrors(display: display)
        
        // 💾 PERSISTENCE: Save display state after disconnect
        DisplayPersistenceService.shared.saveDisplayStates(displays)
        
        // 🔍 SAFETY CHECK: Ensure built-in display is still active after operation
        _ = BuiltInDisplayGuard.shared.ensureBuiltInDisplayActive()
    }

    
    func disableDisplay(display: DisplayInfo) throws {
        // 🛡️ BUILT-IN DISPLAY PROTECTION (Mirror method)
        let validation = BuiltInDisplayGuard.shared.validateDisplayOperation(display, operation: .mirror)
        
        switch validation {
        case .blocked(let reason):
            throw DisplayError(msg: "🛑️ Built-in Display Protection: \(reason)")
        case .warning(let message):
            print("⚠️ Display Warning: \(message)")
            // Continue with operation but log warning
        case .allowed:
            break
        }
        
        display.state = .pending
        
        do {
            try mirrorDisplay(display)
            gammaService.setZeroGamma(for: display)
            
            // 💾 PERSISTENCE: Save display state after mirror+gamma disable
            // Note: State will be set to .mirrored by GammaUpdateService asynchronously
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
                self?.saveDisplayStates()
            }
        } catch {
            throw DisplayError(msg: "Failed to apply a mirror-based disable to '\(display.name)'.")
        }
        unRegisterMirrors(display: display)
        
        // 🔍 SAFETY CHECK: Ensure built-in display is still active after operation
        _ = BuiltInDisplayGuard.shared.ensureBuiltInDisplayActive()
    }
    
    // 💾 Helper function to save display states
    private func saveDisplayStates() {
        DisplayPersistenceService.shared.saveDisplayStates(displays)
    }
    
    func turnOnDisplay(display: DisplayInfo) throws {
        switch display.state {
        case .disconnected:
            try reconnectDisplay(display: display)
        case .mirrored:
            try enableDisplay(display: display)
        default:
            break
        }
        
        // 💾 PERSISTENCE: Save state after restoring display
        saveDisplayStates()
    }
    
    func resetAllDisplays() {
        for display in displays {
            try? turnOnDisplay(display: display)
        }
        
        // 🔧 ENHANCED ERROR HANDLING: Use wrapper for system restoration APIs
        switch DisplayAPIWrapper.shared.restoreColorSyncSettings() {
        case .success:
            print("✅ Color sync settings restored")
        case .failure(let error):
            print("❌ DisplayAPI Error in resetAllDisplays - ColorSync: \(error)")
        }
        
        switch DisplayAPIWrapper.shared.restorePermanentDisplayConfiguration() {
        case .success:
            print("✅ Permanent display configuration restored")
        case .failure(let error):
            print("❌ DisplayAPI Error in resetAllDisplays - PermanentConfig: \(error)")
        }
        
        // 💾 PERSISTENCE: Save state after resetting all displays
        saveDisplayStates()
        
        print("🔄 Reset all displays and saved state")
    }
    
    /// 🆘 EMERGENCY: Comprehensive display recovery system
    func emergencyDisplayRecovery() -> RecoveryResult {
        print("🆘 EMERGENCY RECOVERY: Starting comprehensive display recovery...")
        
        // Get current state recommendations
        let recommendations = DisplayRecoverySystem.shared.getRecoveryRecommendations()
        for recommendation in recommendations {
            print("📋 \(recommendation)")
        }
        
        // Attempt full recovery
        let result = DisplayRecoverySystem.shared.attemptFullRecovery()
        
        switch result {
        case .success(let message):
            print("✅ RECOVERY SUCCESS: \(message)")
        case .partialSuccess(let message, let remaining):
            print("⚠️ PARTIAL RECOVERY: \(message)")
            print("   Remaining issues: \(remaining.joined(separator: ", "))")
        case .failed(let message):
            print("❌ RECOVERY FAILED: \(message)")
        case .requiresReboot(let message):
            print("🔄 REBOOT REQUIRED: \(message)")
        case .requiresManualIntervention(let message):
            print("🆘 MANUAL INTERVENTION: \(message)")
        }
        
        return result
    }
    
    func unRegisterMirrors(display: DisplayInfo) {
        // 🔧 MEMORY LEAK FIX: Use safe mirror cleanup
        for mirror in display.mirroredTo {
            mirror.state = .active
        }
        
        // Clean up mirror relationships to prevent memory leaks
        display.cleanupMirrorRelationships()
    }
    
}

// MARK: - TurnOn logic

extension DisplaysViewModel {
    fileprivate func reconnectDisplay(display: DisplayInfo) throws {
        var cid: CGDisplayConfigRef?
        let beginStatus = CGBeginDisplayConfiguration(&cid)
        guard beginStatus == .success, let config = cid else {
            throw DisplayError(
                msg: "Failed to begin configuration for '\(display.name)'."
            )
        }
        
        let status = CGSConfigureDisplayEnabled(config, display.id, true)
        guard status == 0 else {
            CGCancelDisplayConfiguration(config)
            throw DisplayError(
                msg: "Failed to reconnect '\(display.name)'."
            )
        }
        
        let completeStatus = CGCompleteDisplayConfiguration(config, .forAppOnly)
        guard completeStatus == .success else {
            throw DisplayError(
                msg: "Failed to complete configuration for '\(display.name)'.")
        }
        
        display.state = .active
    }
    
    fileprivate func enableDisplay(display: DisplayInfo) throws {
        gammaService.restoreGamma(for: display)
        
        do {
            try unmirrorDisplay(display)
            try arrengementCache.restore()
            print("Unmirrored display \(display.name)!")
        } catch {
            throw DisplayError(
                msg: "Failed to enable '\(display.name)'."
            )
        }
        
        display.state = .active
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
        
        // 🔧 MEMORY LEAK FIX: Use safe mirror management
        alternateDisplay.addMirroredDisplay(display)
        print("Successfully mirrored display \(display.name) to \(alternateDisplay.name).")
    }
    
    fileprivate func unmirrorDisplay(_ display: DisplayInfo) throws {
        var configRef: CGDisplayConfigRef?
        let beginConfigError = CGBeginDisplayConfiguration(&configRef)
        guard beginConfigError == .success, let config = configRef else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(beginConfigError.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Failed to begin display configuration."]
            )
        }

        let unmirrorError = CGConfigureDisplayMirrorOfDisplay(config, display.id, kCGNullDirectDisplay)
        guard unmirrorError == .success else {
            CGCancelDisplayConfiguration(config)
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(unmirrorError.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Failed to unmirror display \(display.name)."]
            )
        }

        let completeConfigError = CGCompleteDisplayConfiguration(config, .forAppOnly)
        guard completeConfigError == .success else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(completeConfigError.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Failed to complete display configuration."]
            )
        }

        // 🔧 MEMORY LEAK FIX: Safe mirror relationship cleanup
        if let mirrorSource = display.mirrorSource {
            mirrorSource.removeMirroredDisplay(display)
        }

        print("Successfully unmirrored display \(display.name).")
    }
    
    private func selectAlternateDisplay(excluding currentDisplayID: CGDirectDisplayID) -> DisplayInfo? {
        return displays.first { $0.id != currentDisplayID && $0.state == .active}
    }
}

// MARK: - DisplayConnectionDelegate
extension DisplaysViewModel {
    /// Called when display configuration changes (connection/disconnection)
    func displayConnectionChanged() {
        print("🔄 Display configuration changed - refreshing display list")
        
        // Re-fetch displays to get updated state
        fetchDisplays()
        
        // Save updated state
        saveDisplayStates()
    }
    
    /// Called when a display is connected
    func displayConnected(_ displayID: CGDirectDisplayID) {
        print("➕ Display connected: \(displayID)")
        
        // Check if this is a built-in display coming back
        if BuiltInDisplayGuard.shared.isBuiltInDisplay(displayID) {
            print("🏠 Built-in display reconnected! Ensuring proper state...")
            
            // Remove any persistent disconnected state for built-in display
            DisplayPersistenceService.shared.removeDisplayFromPersistence(displayID)
        }
        
        // Get display name for logging
        var displayName = "Display \(displayID)"
        if let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
            displayName = screen.localizedName
        }
        
        print("🔌 \(displayName) is now available")
        
        // Refresh display list will be handled by displayConnectionChanged()
    }
    
    /// Called when a display is disconnected
    func displayDisconnected(_ displayID: CGDirectDisplayID) {
        print("➖ Display physically disconnected: \(displayID)")
        
        // 🚨 CRITICAL: Built-in display physically disconnected
        if BuiltInDisplayGuard.shared.isBuiltInDisplay(displayID) {
            print("🚨 CRITICAL ALERT: Built-in display physically removed!")
            print("🚨 This indicates hardware failure or system corruption!")
            print("🚨 System may become unusable - REBOOT RECOMMENDED!")
            
            // This is emergency situation - hardware level disconnect
            // App cannot fix this, only reboot might help
            return
        }
        
        // For external displays, this is normal hot-unplug behavior
        if let display = displays.first(where: { $0.id == displayID }) {
            print("📱 External display \(display.name) was hot-unplugged")
            
            // Update the display state to reflect physical disconnection
            display.state = .disconnected
            
            // Save the state so we remember this display existed
            saveDisplayStates()
        }
        
        // Refresh display list will be handled by displayConnectionChanged()
    }
}

// MARK: - SleepWakeDelegate  
extension DisplaysViewModel {
    /// Called when system is preparing for sleep
    func systemWillSleep() {
        print("😴 System will sleep - restoring all displays for safety...")
        
        // 🛡️ CRITICAL SAFETY: Restore ALL displays before sleep
        // This prevents users from being locked out when system wakes up
        
        let disconnectedDisplays = displays.filter { $0.state.isOff() }
        print("🔄 Found \(disconnectedDisplays.count) displays to restore before sleep")
        
        for display in disconnectedDisplays {
            do {
                print("🔄 Restoring display: \(display.name)")
                try turnOnDisplay(display: display)
            } catch {
                print("❌ Failed to restore \(display.name) before sleep: \(error)")
                // Continue with other displays even if one fails
            }
        }
        
        // Additional system-level restoration
        CGDisplayRestoreColorSyncSettings()
        CGRestorePermanentDisplayConfiguration()
        
        // Save current state before sleep
        saveDisplayStates()
        
        print("✅ All displays restored before sleep - system safe to sleep")
    }
    
    /// Called when system is preparing for power off
    func systemWillPowerOff() {
        print("⚡ System will power off - restoring all displays...")
        
        // Same safety measures as sleep
        systemWillSleep()
        
        print("✅ All displays restored before power off")
    }
    
    /// Called when system wakes from sleep
    func systemDidWake() {
        print("☀️ System woke from sleep - checking display states...")
        
        // Re-fetch display configuration (hardware may have changed during sleep)
        fetchDisplays()
        
        // Verify built-in display is active
        let builtInStatus = BuiltInDisplayGuard.shared.ensureBuiltInDisplayActive()
        if !builtInStatus {
            print("🚨 WARNING: Built-in display not detected after wake!")
        }
        
        // Check if any external displays were connected/disconnected during sleep
        let activeCount = displays.filter { $0.state == .active }.count
        let disconnectedCount = displays.filter { $0.state.isOff() }.count
        
        print("📱 Wake status: \(activeCount) active, \(disconnectedCount) disconnected displays")
        
        // Save updated state
        saveDisplayStates()
        
        print("✅ Post-wake display state check completed")
    }
}

// MARK: - EmergencyHotkeyDelegate
extension DisplaysViewModel {
    /// Called when emergency hotkey is pressed (Cmd+Option+Shift+L)
    func emergencyRecoveryTriggered() {
        print("🚨 EMERGENCY RECOVERY TRIGGERED BY HOTKEY!")
        
        // Show emergency instructions
        let instructions = EmergencyHotkeyManager.shared.showEmergencyInstructions()
        print(instructions)
        
        // Trigger comprehensive recovery
        let result = emergencyDisplayRecovery()
        
        // Additional emergency-specific actions
        switch result {
        case .success:
            print("🎉 Emergency recovery successful via hotkey!")
            NSSound.beep() // Success sound
            
        case .partialSuccess(let message, let remaining):
            print("⚠️ Emergency recovery partially successful: \(message)")
            print("   Manual steps may be required: \(remaining.joined(separator: ", "))")
            
        case .failed:
            print("❌ Emergency recovery failed via hotkey")
            print("🆘 CRITICAL: Manual intervention required")
            NSSound.beep() // Error sound
            NSSound.beep() // Double beep for failure
            
        case .requiresReboot(let message):
            print("🔄 Emergency recovery requires reboot: \(message)")
            NSSound.beep() // Single beep for reboot needed
            
        case .requiresManualIntervention(let message):
            print("🆘 Emergency recovery requires manual steps: \(message)")
            NSSound.beep() // Double beep for manual intervention
            NSSound.beep()
        }
        
        // Force refresh display state after emergency recovery
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.fetchDisplays()
        }
    }
}

// MARK: - NScreen Extentrion

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as! CGDirectDisplayID
    }
}
