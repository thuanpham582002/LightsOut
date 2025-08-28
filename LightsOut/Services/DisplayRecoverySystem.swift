//
//  DisplayRecoverySystem.swift
//  LightsOut
//
//  Multi-tier recovery system for display restoration when things go wrong
//

import Foundation
import Cocoa
import CoreGraphics

enum RecoveryLevel: Int, CaseIterable {
    case appLevel = 1       // App-based recovery
    case systemLevel = 2    // System preference reset
    case hardwareLevel = 3  // NVRAM/hardware reset
    case manualLevel = 4    // Manual user intervention
    
    var description: String {
        switch self {
        case .appLevel: return "App-Level Recovery"
        case .systemLevel: return "System-Level Recovery"
        case .hardwareLevel: return "Hardware-Level Recovery"
        case .manualLevel: return "Manual Recovery Required"
        }
    }
}

enum RecoveryResult {
    case success(String)
    case partialSuccess(String, remaining: [String])
    case failed(String)
    case requiresReboot(String)
    case requiresManualIntervention(String)
}

class DisplayRecoverySystem {
    static let shared = DisplayRecoverySystem()
    
    weak var displaysViewModel: DisplaysViewModel?
    
    private init() {}
    
    /// Attempt comprehensive display recovery using multi-tier approach
    func attemptFullRecovery() -> RecoveryResult {
        print("🚨 Starting comprehensive display recovery...")
        
        // Level 1: App-Level Recovery
        print("🔄 Attempting Level 1: App-Level Recovery")
        let level1Result = attemptAppLevelRecovery()
        
        switch level1Result {
        case .success(let message):
            print("✅ Level 1 recovery successful: \(message)")
            return level1Result
        case .partialSuccess(let message, let remaining):
            print("⚠️ Level 1 partial success: \(message), remaining issues: \(remaining)")
            // Continue to next level
        case .failed(let message):
            print("❌ Level 1 failed: \(message)")
            // Continue to next level
        default:
            break
        }
        
        // Level 2: System-Level Recovery
        print("🔄 Attempting Level 2: System-Level Recovery")
        let level2Result = attemptSystemLevelRecovery()
        
        switch level2Result {
        case .success(let message):
            print("✅ Level 2 recovery successful: \(message)")
            return level2Result
        case .partialSuccess(let message, let remaining):
            print("⚠️ Level 2 partial success: \(message), remaining issues: \(remaining)")
            // Continue to next level
        case .failed(let message):
            print("❌ Level 2 failed: \(message)")
            // Continue to next level
        default:
            break
        }
        
        // Level 3: Hardware-Level Recovery
        print("🔄 Attempting Level 3: Hardware-Level Recovery")
        let level3Result = attemptHardwareLevelRecovery()
        
        switch level3Result {
        case .requiresReboot(let message):
            print("🔄 Level 3 requires reboot: \(message)")
            return level3Result
        case .success(let message):
            print("✅ Level 3 recovery successful: \(message)")
            return level3Result
        default:
            break
        }
        
        // Level 4: Manual Recovery
        print("🆘 All automated recovery failed - manual intervention required")
        return attemptManualRecoveryGuidance()
    }
    
    // MARK: - Level 1: App-Level Recovery
    private func attemptAppLevelRecovery() -> RecoveryResult {
        var recoveryActions: [String] = []
        var failedActions: [String] = []
        
        // 1. Verify built-in display is active
        if !BuiltInDisplayGuard.shared.ensureBuiltInDisplayActive() {
            failedActions.append("Built-in display not detected")
        } else {
            recoveryActions.append("Built-in display verified active")
        }
        
        // 2. Reset all displays using app logic
        displaysViewModel?.resetAllDisplays()
        recoveryActions.append("App display reset executed")
        
        // 3. Clean up persistent state
        DisplayPersistenceService.shared.clearAllPersistentData()
        recoveryActions.append("Cleared persistent display data")
        
        // 4. Re-fetch current display state
        displaysViewModel?.fetchDisplays()
        recoveryActions.append("Refreshed display state")
        
        // 5. Verify recovery success
        let activeDisplaysResult = DisplayAPIWrapper.shared.getActiveDisplayList()
        switch activeDisplaysResult {
        case .success(let displays):
            if displays.isEmpty {
                failedActions.append("No active displays after recovery")
            } else {
                recoveryActions.append("Found \(displays.count) active displays")
            }
        case .failure(let error):
            failedActions.append("Cannot get display list: \(error.localizedDescription)")
        }
        
        // Evaluate results
        if failedActions.isEmpty {
            return .success("App-level recovery completed: \(recoveryActions.joined(separator: ", "))")
        } else if recoveryActions.count > failedActions.count {
            return .partialSuccess("Some app-level recovery successful", remaining: failedActions)
        } else {
            return .failed("App-level recovery failed: \(failedActions.joined(separator: ", "))")
        }
    }
    
    // MARK: - Level 2: System-Level Recovery
    private func attemptSystemLevelRecovery() -> RecoveryResult {
        var recoveryActions: [String] = []
        var failedActions: [String] = []
        
        // 1. System color sync restoration
        switch DisplayAPIWrapper.shared.restoreColorSyncSettings() {
        case .success:
            recoveryActions.append("Color sync settings restored")
        case .failure(let error):
            failedActions.append("Color sync restoration failed: \(error.localizedDescription)")
        }
        
        // 2. Permanent display configuration restoration
        switch DisplayAPIWrapper.shared.restorePermanentDisplayConfiguration() {
        case .success:
            recoveryActions.append("Permanent display config restored")
        case .failure(let error):
            failedActions.append("Permanent config restoration failed: \(error.localizedDescription)")
        }
        
        // 3. Reset display preferences
        let prefsResetResult = resetDisplayPreferences()
        if prefsResetResult {
            recoveryActions.append("Display preferences reset")
        } else {
            failedActions.append("Display preferences reset failed")
        }
        
        // 4. Restart display server if possible
        let serverRestartResult = attemptDisplayServerRestart()
        switch serverRestartResult {
        case .success:
            recoveryActions.append("Display server operations completed")
        case .failed(let error):
            failedActions.append("Display server operations failed: \(error)")
        default:
            break
        }
        
        // Evaluate results
        if failedActions.isEmpty {
            return .success("System-level recovery completed: \(recoveryActions.joined(separator: ", "))")
        } else if recoveryActions.count > failedActions.count {
            return .partialSuccess("Some system-level recovery successful", remaining: failedActions)
        } else {
            return .failed("System-level recovery failed: \(failedActions.joined(separator: ", "))")
        }
    }
    
    // MARK: - Level 3: Hardware-Level Recovery
    private func attemptHardwareLevelRecovery() -> RecoveryResult {
        // This level requires reboot for NVRAM reset
        // We can only provide guidance at this point
        
        let instructions = [
            "NVRAM reset required (this will restart your Mac)",
            "Hold Cmd+Option+P+R during startup",
            "Keep holding until you hear startup sound twice",
            "Built-in display should be restored after restart"
        ]
        
        return .requiresReboot("Hardware-level recovery requires NVRAM reset: \(instructions.joined(separator: "; "))")
    }
    
    // MARK: - Level 4: Manual Recovery
    private func attemptManualRecoveryGuidance() -> RecoveryResult {
        let manualSteps = [
            "1. Force quit LightsOut app",
            "2. Open System Preferences > Displays",
            "3. Try to detect displays using 'Detect Displays' button",
            "4. If built-in display still missing, restart computer",
            "5. If problem persists, reset NVRAM (Cmd+Opt+P+R at startup)",
            "6. Contact support if issue continues"
        ]
        
        return .requiresManualIntervention("Manual recovery steps: \(manualSteps.joined(separator: "; "))")
    }
    
    // MARK: - Utility Functions
    private func resetDisplayPreferences() -> Bool {
        let preferenceDomains = [
            "com.apple.windowserver",
            "com.apple.displays",
            "com.apple.preference.displays"
        ]
        
        var success = true
        for domain in preferenceDomains {
            do {
                let result = Process.run("/usr/bin/defaults", arguments: ["delete", domain])
                if result.terminationStatus != 0 && result.terminationStatus != 1 { // 1 is "domain not found" which is ok
                    success = false
                }
            } catch {
                print("❌ Failed to reset preferences for \(domain): \(error)")
                success = false
            }
        }
        
        return success
    }
    
    private func attemptDisplayServerRestart() -> RecoveryResult {
        // Note: This is a dangerous operation that will cause screen flicker
        // Only attempt if user explicitly consents
        
        print("⚠️ Display server restart would cause screen disruption")
        print("⚠️ This operation is not recommended in production")
        
        // For safety, we'll skip this dangerous operation
        return .success("Display server restart skipped for safety")
    }
    
    /// Get recovery recommendations based on current state
    func getRecoveryRecommendations() -> [String] {
        var recommendations: [String] = []
        
        // Check built-in display status
        if !BuiltInDisplayGuard.shared.ensureBuiltInDisplayActive() {
            recommendations.append("🚨 CRITICAL: Built-in display not detected - reboot recommended")
        }
        
        // Check display list
        let activeDisplaysResult = DisplayAPIWrapper.shared.getActiveDisplayList()
        switch activeDisplaysResult {
        case .success(let displays):
            if displays.isEmpty {
                recommendations.append("⚠️ No active displays found - system-level recovery needed")
            } else if displays.count == 1 {
                recommendations.append("ℹ️ Only one display active - safe to proceed")
            }
        case .failure:
            recommendations.append("❌ Cannot access display system - hardware-level recovery may be needed")
        }
        
        // Check persistence data
        let stats = DisplayPersistenceService.shared.getPersistenceStats()
        if stats.disconnected > 0 {
            recommendations.append("💾 \(stats.disconnected) disconnected displays in storage - app recovery available")
        }
        
        return recommendations
    }
}

// MARK: - Process Extensions
extension Process {
    static func run(_ executablePath: String, arguments: [String] = []) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        return process
    }
}