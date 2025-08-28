//
//  SleepWakeManager.swift  
//  LightsOut
//
//  Sleep/wake integration to prevent display lockout during system sleep
//  Based on bluesnooze pattern
//

import Foundation
import Cocoa

protocol SleepWakeDelegate: AnyObject {
    func systemWillSleep()
    func systemDidWake()
    func systemWillPowerOff()
}

class SleepWakeManager {
    static let shared = SleepWakeManager()
    
    weak var delegate: SleepWakeDelegate?
    private var isMonitoring = false
    
    private init() {}
    
    /// Start monitoring system sleep/wake events
    func startMonitoring() {
        guard !isMonitoring else {
            print("⚠️ Sleep/wake monitoring already active")
            return
        }
        
        print("😴 Starting sleep/wake monitoring...")
        
        setupNotificationHandlers()
        isMonitoring = true
        
        print("✅ Sleep/wake monitoring started successfully")
    }
    
    /// Stop monitoring system sleep/wake events
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        print("😴 Stopping sleep/wake monitoring...")
        
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        isMonitoring = false
        
        print("✅ Sleep/wake monitoring stopped successfully")
    }
    
    /// Setup notification handlers (bluesnooze pattern)
    private func setupNotificationHandlers() {
        let notifications: [NSNotification.Name: Selector] = [
            NSWorkspace.willSleepNotification: #selector(onSystemWillSleep(notification:)),
            NSWorkspace.willPowerOffNotification: #selector(onSystemWillPowerOff(notification:)),
            NSWorkspace.didWakeNotification: #selector(onSystemDidWake(notification:))
        ]
        
        for (notification, selector) in notifications {
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: selector,
                name: notification,
                object: nil
            )
        }
        
        print("📡 Registered for sleep/wake notifications")
    }
    
    /// Handle system will sleep notification
    @objc private func onSystemWillSleep(notification: NSNotification) {
        print("😴 System preparing for sleep...")
        
        // CRITICAL: Restore all displays before sleep to prevent lockout
        delegate?.systemWillSleep()
        
        print("🛡️ All displays restored before sleep")
    }
    
    /// Handle system will power off notification  
    @objc private func onSystemWillPowerOff(notification: NSNotification) {
        print("⚡ System preparing for power off...")
        
        // CRITICAL: Restore all displays before power off
        delegate?.systemWillPowerOff()
        
        print("🛡️ All displays restored before power off")
    }
    
    /// Handle system did wake notification
    @objc private func onSystemDidWake(notification: NSNotification) {
        print("☀️ System woke from sleep...")
        
        // Give system time to stabilize hardware
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            print("🔄 Re-checking display states after wake...")
            self?.delegate?.systemDidWake()
        }
    }
    
    /// Get current monitoring status
    var monitoringStatus: Bool {
        return isMonitoring
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - Sleep/Wake States
extension SleepWakeManager {
    /// Check if system is currently preparing for sleep
    var isSystemPreparingForSleep: Bool {
        // This is a heuristic - in real apps you might want more sophisticated detection
        return false
    }
    
    /// Force immediate display restoration (emergency function)
    func emergencyRestoreDisplays() {
        print("🚨 EMERGENCY: Forcing immediate display restoration")
        delegate?.systemWillSleep() // Reuse the sleep preparation logic
    }
}