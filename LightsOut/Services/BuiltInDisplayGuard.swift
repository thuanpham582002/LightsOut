//
//  BuiltInDisplayGuard.swift
//  LightsOut
//
//  Built-in display protection service to prevent system lockout
//

import CoreGraphics
import Foundation

enum ValidationResult {
    case allowed
    case blocked(reason: String)
    case warning(message: String)
}

enum DisplayOperation {
    case disconnect
    case mirror  
    case gamma
}

class BuiltInDisplayGuard {
    static let shared = BuiltInDisplayGuard()
    
    private init() {}
    
    /// Check if a display is the built-in display
    func isBuiltInDisplay(_ displayID: CGDirectDisplayID) -> Bool {
        return CGDisplayIsBuiltin(displayID) != 0
    }
    
    /// Get count of active displays
    private func getActiveDisplayCount() -> Int {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        return Int(displayCount)
    }
    
    /// Validate if an operation is safe to perform on a display
    func validateDisplayOperation(_ display: DisplayInfo, operation: DisplayOperation) -> ValidationResult {
        let displayID = display.id
        
        // CRITICAL RULE: Never disconnect built-in display
        if isBuiltInDisplay(displayID) && operation == .disconnect {
            return .blocked(reason: "Cannot disconnect built-in display. This would make the system unusable and require a reboot to recover.")
        }
        
        // SAFETY RULE: Don't disconnect last remaining display
        if operation == .disconnect && getActiveDisplayCount() <= 1 {
            return .blocked(reason: "Cannot disconnect the last remaining display. At least one display must remain active.")
        }
        
        // WARNING: Disconnecting primary display while built-in is mirrored
        if display.isPrimary && operation == .disconnect {
            if hasBuiltInDisplayMirrored() {
                return .warning(message: "Disconnecting primary display while built-in display is mirrored may cause display issues.")
            }
        }
        
        return .allowed
    }
    
    /// Check if built-in display is currently mirrored
    private func hasBuiltInDisplayMirrored() -> Bool {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &activeDisplays, &displayCount)
        
        for displayID in activeDisplays {
            if isBuiltInDisplay(displayID) {
                // Check if this display is mirrored to another
                let mirrorSource = CGDisplayMirrorsDisplay(displayID)
                return mirrorSource != kCGNullDirectDisplay
            }
        }
        return false
    }
    
    /// Find built-in display ID if available
    func getBuiltInDisplayID() -> CGDirectDisplayID? {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &activeDisplays, &displayCount)
        
        for displayID in activeDisplays {
            if isBuiltInDisplay(displayID) {
                return displayID
            }
        }
        return nil
    }
    
    /// Emergency check: ensure built-in display is always enabled
    func ensureBuiltInDisplayActive() -> Bool {
        guard let builtInID = getBuiltInDisplayID() else {
            print("WARNING: Built-in display not found in active display list!")
            return false
        }
        
        // Built-in display found and active
        print("Built-in display (ID: \(builtInID)) is active")
        return true
    }
}

// MARK: - Display Error Extensions
extension DisplayError {
    static func builtInDisplayProtection(_ message: String) -> DisplayError {
        return DisplayError(msg: "🛡️ Built-in Display Protection: \(message)")
    }
}