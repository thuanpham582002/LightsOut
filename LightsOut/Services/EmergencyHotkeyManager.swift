//
//  EmergencyHotkeyManager.swift
//  LightsOut
//
//  Emergency global hotkey for display recovery when UI is not visible
//

import Cocoa
import Carbon
import Foundation

protocol EmergencyHotkeyDelegate: AnyObject {
    func emergencyRecoveryTriggered()
}

class EmergencyHotkeyManager {
    static let shared = EmergencyHotkeyManager()
    
    weak var delegate: EmergencyHotkeyDelegate?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var isActive = false
    
    // Emergency hotkey: Cmd+Option+Shift+L (hard to press accidentally)
    private let keyCode: UInt32 = 37 // L key
    private let modifierFlags: UInt32 = UInt32(cmdKey | optionKey | shiftKey)
    
    private init() {}
    
    /// Start monitoring for emergency hotkey
    func startMonitoring() {
        guard !isActive else {
            print("⚠️ Emergency hotkey already active")
            return
        }
        
        print("🔥 Setting up emergency hotkey: Cmd+Option+Shift+L")
        
        // Install event handler
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            emergencyHotkeyHandler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandler
        )
        
        guard status == noErr else {
            print("❌ Failed to install emergency hotkey event handler: \(status)")
            return
        }
        
        // Register hotkey
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4C4F4C44) // 'LOLD' 
        hotKeyID.id = 1
        
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifierFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        
        guard registerStatus == noErr else {
            print("❌ Failed to register emergency hotkey: \(registerStatus)")
            return
        }
        
        isActive = true
        print("✅ Emergency hotkey active: Cmd+Option+Shift+L")
        print("🆘 Press Cmd+Option+Shift+L to trigger emergency display recovery")
    }
    
    /// Stop monitoring emergency hotkey
    func stopMonitoring() {
        guard isActive else { return }
        
        print("🔥 Stopping emergency hotkey monitoring...")
        
        // Unregister hotkey
        if let hotKeyRef = hotKeyRef {
            let status = UnregisterEventHotKey(hotKeyRef)
            if status != noErr {
                print("⚠️ Failed to unregister hotkey: \(status)")
            }
            self.hotKeyRef = nil
        }
        
        // Remove event handler
        if let eventHandler = eventHandler {
            let status = RemoveEventHandler(eventHandler)
            if status != noErr {
                print("⚠️ Failed to remove event handler: \(status)")
            }
            self.eventHandler = nil
        }
        
        isActive = false
        print("✅ Emergency hotkey monitoring stopped")
    }
    
    /// Handle emergency hotkey press
    private func handleEmergencyHotkey() {
        print("🚨 EMERGENCY HOTKEY TRIGGERED: Cmd+Option+Shift+L pressed!")
        print("🆘 Initiating emergency display recovery...")
        
        // Play system sound to confirm hotkey was received
        NSSound.beep()
        
        // Brief delay to ensure sound plays
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            // Trigger emergency recovery through delegate
            self?.delegate?.emergencyRecoveryTriggered()
        }
    }
    
    /// Check if emergency hotkey is currently active
    var isMonitoring: Bool {
        return isActive
    }
    
    /// Get hotkey description for user
    var hotkeyDescription: String {
        return "Cmd+Option+Shift+L"
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - C Callback Function
/// C callback function for emergency hotkey events
private func emergencyHotkeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    
    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
    
    let manager = Unmanaged<EmergencyHotkeyManager>.fromOpaque(userData).takeUnretained()
    
    // Verify this is the hotkey event we're expecting
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    
    guard status == noErr else {
        print("⚠️ Failed to get hotkey event parameter: \(status)")
        return OSStatus(eventNotHandledErr)
    }
    
    // Check if this is our emergency hotkey
    if hotKeyID.signature == OSType(0x4C4F4C44) && hotKeyID.id == 1 {
        manager.handleEmergencyHotkey()
        return noErr
    }
    
    return OSStatus(eventNotHandledErr)
}

// MARK: - Emergency Recovery Extensions
extension EmergencyHotkeyManager {
    /// Test emergency hotkey functionality
    func testEmergencyHotkey() {
        print("🧪 Testing emergency hotkey functionality...")
        handleEmergencyHotkey()
    }
    
    /// Show emergency instructions to user
    func showEmergencyInstructions() -> String {
        return """
        🆘 EMERGENCY DISPLAY RECOVERY INSTRUCTIONS:
        
        If your screen goes black or displays are not visible:
        1. Press and hold: Cmd+Option+Shift+L
        2. Listen for system beep sound (confirms hotkey received)
        3. Wait 10-15 seconds for automatic recovery
        4. If recovery fails, restart your Mac
        
        CRITICAL: Built-in display should NEVER be disabled
        If built-in display is lost, only reboot can recover it.
        """
    }
}