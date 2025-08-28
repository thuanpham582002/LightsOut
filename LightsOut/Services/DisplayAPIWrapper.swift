//
//  DisplayAPIWrapper.swift
//  LightsOut
//
//  Comprehensive error handling wrapper for Core Graphics Display APIs
//

import CoreGraphics
import Foundation

/// Enhanced error types for display operations
enum DisplayAPIError: Error, LocalizedError {
    case configurationFailed(CGError)
    case apiCallFailed(String, Int32)
    case invalidDisplayID(CGDirectDisplayID)
    case insufficientPermissions
    case systemResourceExhausted
    case displayNotFound(CGDirectDisplayID)
    case operationTimedOut
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .configurationFailed(let cgError):
            return "Display configuration failed: \(cgError.localizedDescription)"
        case .apiCallFailed(let apiName, let code):
            return "\(apiName) failed with code \(code)"
        case .invalidDisplayID(let displayID):
            return "Invalid display ID: \(displayID)"
        case .insufficientPermissions:
            return "Insufficient permissions for display operation"
        case .systemResourceExhausted:
            return "System resources exhausted"
        case .displayNotFound(let displayID):
            return "Display not found: \(displayID)"
        case .operationTimedOut:
            return "Display operation timed out"
        case .unknown(let message):
            return "Unknown display error: \(message)"
        }
    }
}

/// Safe wrapper for Core Graphics Display APIs
class DisplayAPIWrapper {
    static let shared = DisplayAPIWrapper()
    
    private init() {}
    
    // MARK: - Display Configuration APIs
    
    /// Safe wrapper for CGBeginDisplayConfiguration
    func beginDisplayConfiguration() -> Result<CGDisplayConfigRef, DisplayAPIError> {
        var config: CGDisplayConfigRef?
        let result = CGBeginDisplayConfiguration(&config)
        
        switch result {
        case .success:
            guard let config = config else {
                return .failure(.unknown("CGBeginDisplayConfiguration returned success but config is nil"))
            }
            return .success(config)
        default:
            return .failure(.configurationFailed(result))
        }
    }
    
    /// Safe wrapper for CGCompleteDisplayConfiguration
    func completeDisplayConfiguration(_ config: CGDisplayConfigRef, option: CGConfigureOption) -> Result<Void, DisplayAPIError> {
        let result = CGCompleteDisplayConfiguration(config, option)
        
        switch result {
        case .success:
            return .success(())
        default:
            return .failure(.configurationFailed(result))
        }
    }
    
    /// Safe wrapper for CGCancelDisplayConfiguration
    func cancelDisplayConfiguration(_ config: CGDisplayConfigRef) -> Result<Void, DisplayAPIError> {
        let result = CGCancelDisplayConfiguration(config)
        
        switch result {
        case .success:
            return .success(())
        default:
            return .failure(.configurationFailed(result))
        }
    }
    
    // MARK: - Display Enable/Disable APIs
    
    /// Safe wrapper for CGSConfigureDisplayEnabled (private API)
    func configureDisplayEnabled(_ config: CGDisplayConfigRef, displayID: CGDirectDisplayID, enabled: Bool) -> Result<Void, DisplayAPIError> {
        let result = CGSConfigureDisplayEnabled(config, displayID, enabled)
        
        if result == 0 {
            return .success(())
        } else {
            let operation = enabled ? "enable" : "disable"
            return .failure(.apiCallFailed("CGSConfigureDisplayEnabled(\(operation))", Int32(result)))
        }
    }
    
    // MARK: - Display Mirroring APIs
    
    /// Safe wrapper for CGConfigureDisplayMirrorOfDisplay
    func configureDisplayMirror(_ config: CGDisplayConfigRef, display: CGDirectDisplayID, masterDisplay: CGDirectDisplayID) -> Result<Void, DisplayAPIError> {
        let result = CGConfigureDisplayMirrorOfDisplay(config, display, masterDisplay)
        
        switch result {
        case .success:
            return .success(())
        default:
            return .failure(.configurationFailed(result))
        }
    }
    
    // MARK: - Display Gamma APIs
    
    /// Safe wrapper for CGSetDisplayTransferByTable
    func setDisplayGamma(_ displayID: CGDirectDisplayID, tableSize: UInt32, redTable: [CGGammaValue], greenTable: [CGGammaValue], blueTable: [CGGammaValue]) -> Result<Void, DisplayAPIError> {
        let result = CGSetDisplayTransferByTable(displayID, tableSize, redTable, greenTable, blueTable)
        
        switch result {
        case .success:
            return .success(())
        default:
            return .failure(.configurationFailed(result))
        }
    }
    
    /// Safe wrapper for CGGetDisplayTransferByTable
    func getDisplayGamma(_ displayID: CGDirectDisplayID) -> Result<(red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue]), DisplayAPIError> {
        var gammaTableSize: UInt32 = 256
        
        // First get the actual table size
        let sizeResult = CGGetDisplayTransferByTable(displayID, 0, nil, nil, nil, &gammaTableSize)
        guard sizeResult == .success else {
            return .failure(.configurationFailed(sizeResult))
        }
        
        // Allocate tables with correct size
        var redTable = [CGGammaValue](repeating: 0, count: Int(gammaTableSize))
        var greenTable = [CGGammaValue](repeating: 0, count: Int(gammaTableSize))
        var blueTable = [CGGammaValue](repeating: 0, count: Int(gammaTableSize))
        
        // Get the actual gamma tables
        let result = CGGetDisplayTransferByTable(displayID, gammaTableSize, &redTable, &greenTable, &blueTable, &gammaTableSize)
        
        switch result {
        case .success:
            return .success((red: redTable, green: greenTable, blue: blueTable))
        default:
            return .failure(.configurationFailed(result))
        }
    }
    
    // MARK: - Display Information APIs
    
    /// Safe wrapper for CGGetActiveDisplayList
    func getActiveDisplayList() -> Result<[CGDirectDisplayID], DisplayAPIError> {
        var displayCount: UInt32 = 0
        
        // First get the count
        let countResult = CGGetActiveDisplayList(0, nil, &displayCount)
        guard countResult == .success else {
            return .failure(.configurationFailed(countResult))
        }
        
        guard displayCount > 0 else {
            return .success([]) // No displays is valid, just return empty array
        }
        
        // Allocate array and get actual display IDs
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        let result = CGGetActiveDisplayList(displayCount, &activeDisplays, &displayCount)
        
        switch result {
        case .success:
            return .success(Array(activeDisplays.prefix(Int(displayCount))))
        default:
            return .failure(.configurationFailed(result))
        }
    }
    
    /// Validate that a display ID is currently active
    func validateDisplayID(_ displayID: CGDirectDisplayID) -> Result<Bool, DisplayAPIError> {
        switch getActiveDisplayList() {
        case .success(let displays):
            return .success(displays.contains(displayID))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: - System Restoration APIs
    
    /// Safe wrapper for CGDisplayRestoreColorSyncSettings
    func restoreColorSyncSettings() -> Result<Void, DisplayAPIError> {
        CGDisplayRestoreColorSyncSettings()
        return .success(()) // This API doesn't return error codes
    }
    
    /// Safe wrapper for CGRestorePermanentDisplayConfiguration  
    func restorePermanentDisplayConfiguration() -> Result<Void, DisplayAPIError> {
        // CGRestorePermanentDisplayConfiguration() returns Void in macOS 14
        CGRestorePermanentDisplayConfiguration()
        return .success(())
    }
    }

// MARK: - CGError Extensions
extension CGError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .success: return "Success"
        case .failure: return "Generic failure"
        case .illegalArgument: return "Illegal argument"
        case .invalidConnection: return "Invalid connection"
        case .invalidContext: return "Invalid context"
        case .cannotComplete: return "Cannot complete operation"
        case .notImplemented: return "Not implemented"
        case .rangeCheck: return "Range check error"
        case .typeCheck: return "Type check error"
        case .invalidOperation: return "Invalid operation"
        case .noneAvailable: return "None available"
        @unknown default: return "Unknown CG error (\(rawValue))"
        }
    }
}