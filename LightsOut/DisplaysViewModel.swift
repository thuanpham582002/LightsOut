//
//  DisplaysViewModel.swift
//  BlackoutTest

import CoreGraphics
import SwiftUI

@_silgen_name("CGSConfigureDisplayEnabled")
func CGSConfigureDisplayEnabled(_ cid: CGDisplayConfigRef, _ display: UInt32, _ enabled: Bool) -> Int

class DisplaysViewModel: ObservableObject {
    @Published var displays: [DisplayInfo] = []
    private var gammaService = GammaUpdateService()
    private var arrengementCache = DisplayArrangementCacheService()
    
    init() {
        fetchDisplays()
    }
    
    func fetchDisplays() {
        print("Fetching displays.")
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        let allocated = Int(displayCount)
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: allocated)
        CGGetActiveDisplayList(displayCount, &activeDisplays, &displayCount)
        
        let primaryDisplayID = CGMainDisplayID()
        
        displays = activeDisplays.compactMap { displayID in
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
        }
    }
    
    func hardDisableDisplay(displayID: CGDirectDisplayID) {
        var cid: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&cid)
        
        let status = CGSConfigureDisplayEnabled(cid!, displayID, false)
        
        print(status)
        
        CGCompleteDisplayConfiguration(cid, CGConfigureOption.forAppOnly)
    }
    
    func hardEnableDisplay(displayID: CGDirectDisplayID) {
        var cid: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&cid)
        
        let status = CGSConfigureDisplayEnabled(cid!, displayID, true)
        
        print(status)
        
        CGCompleteDisplayConfiguration(cid, CGConfigureOption.forAppOnly)
    }
    
    func softDisableDisplay(display: DisplayInfo) {
        do {
            try arrengementCache.cache()
            try mirrorDisplay(targetDisplayID: display.id)
            print("Mirrored display \(display.name)!")
            gammaService.setZeroGamma(for: display)
        } catch {
            print("Failed to mirror display: \(error.localizedDescription)")
        }
    }
    
    func unSoftDisableDisplay(display: DisplayInfo) {
        gammaService.restoreGamma(for: display)
        
        do {
            try unmirrorDisplay(display.id)
            try arrengementCache.restore()
            print("Unmirrored display!")
        } catch {
            print("Failed to unmirror display: \(error.localizedDescription)")
        }
        
        display.state = .active
    }
    
    func resetAllDisplays() {
        for display in displays {
            unSoftDisableDisplay(display: display)
        }
        CGDisplayRestoreColorSyncSettings()
        CGRestorePermanentDisplayConfiguration()
    }
}

// MARK: - Mirroring Extention

extension DisplaysViewModel {
    fileprivate func mirrorDisplay(targetDisplayID: CGDirectDisplayID) throws {
        guard let alternateDisplayID = selectAlternateDisplay(excluding: targetDisplayID) else {
            print("No suitable alternate display found for mirroring.")
            return
        }
        
        var configRef: CGDisplayConfigRef?
        let beginConfigError = CGBeginDisplayConfiguration(&configRef)
        guard beginConfigError == .success, let config = configRef else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(beginConfigError.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to begin display configuration."
            ])
        }
        
        let mirrorError = CGConfigureDisplayMirrorOfDisplay(config, targetDisplayID, alternateDisplayID)
        guard mirrorError == .success else {
            CGCancelDisplayConfiguration(config)
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(mirrorError.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to mirror display \(alternateDisplayID) to display \(targetDisplayID)."
            ])
        }
        
        let completeConfigError = CGCompleteDisplayConfiguration(config, .permanently)
        guard completeConfigError == .success else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(completeConfigError.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to complete display configuration."
            ])
        }
        print("Successfully mirrored display \(alternateDisplayID) to \(targetDisplayID).")
    }
    
    fileprivate func unmirrorDisplay(_ targetDisplayID: CGDirectDisplayID) throws {
        var configRef: CGDisplayConfigRef?
        let beginConfigError = CGBeginDisplayConfiguration(&configRef)
        guard beginConfigError == .success, let config = configRef else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(beginConfigError.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to begin display configuration."
            ])
        }
        
        let unmirrorError = CGConfigureDisplayMirrorOfDisplay(config, targetDisplayID, kCGNullDirectDisplay)
        guard unmirrorError == .success else {
            CGCancelDisplayConfiguration(config)
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(unmirrorError.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to unmirror display ID \(targetDisplayID)."
            ])
        }
        
        let completeConfigError = CGCompleteDisplayConfiguration(config, .permanently)
        guard completeConfigError == .success else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(completeConfigError.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to complete display configuration."
            ])
        }
        print("Successfully unmirrored display \(targetDisplayID).")
    }
    
    private func selectAlternateDisplay(excluding primaryDisplayID: CGDirectDisplayID) -> CGDirectDisplayID? {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &activeDisplays, &displayCount)
        
        return activeDisplays.first { $0 != primaryDisplayID }
    }
}

// MARK: - NScreen Extentrion

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as! CGDirectDisplayID
    }
}
