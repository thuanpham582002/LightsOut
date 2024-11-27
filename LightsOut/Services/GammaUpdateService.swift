//
//  GammaUpdateService.swift
//  BlackoutTest
//
//  Created by Alon Natapov on 26/11/2024.
//
import CoreGraphics
import SwiftUI

class GammaUpdateService {
    @Published var originalGammaTables: [CGDirectDisplayID: (red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue])] = [:]
    private var gammaUpdateTimers: [CGDirectDisplayID: Timer] = [:]
    
    func setZeroGamma(for displayID: CGDirectDisplayID) {
        saveOriginalGamma(for: displayID)
        startGammaUpdateTimer(for: displayID)
    }
    
    func restoreGamma(for displayID: CGDirectDisplayID) {
        gammaUpdateTimers[displayID]?.invalidate()
        gammaUpdateTimers[displayID] = nil
        
        if let originalTables = originalGammaTables[displayID] {
            CGSetDisplayTransferByTable(displayID, UInt32(originalTables.red.count), originalTables.red, originalTables.green, originalTables.blue)
        } else {
            print("No original gamma table saved for display \(displayID).")
        }
    }
    
    private func saveOriginalGamma(for displayID: CGDirectDisplayID) {
        if originalGammaTables[displayID] == nil {
            var gammaTableSize: UInt32 = 256
            CGGetDisplayTransferByTable(displayID, 0, nil, nil, nil, &gammaTableSize)
            var redTable = [CGGammaValue](repeating: 0, count: Int(gammaTableSize))
            var greenTable = [CGGammaValue](repeating: 0, count: Int(gammaTableSize))
            var blueTable = [CGGammaValue](repeating: 0, count: Int(gammaTableSize))
            CGGetDisplayTransferByTable(displayID, gammaTableSize, &redTable, &greenTable, &blueTable, &gammaTableSize)
            originalGammaTables[displayID] = (red: redTable, green: greenTable, blue: blueTable)
        }
    }
    
    private func startGammaUpdateTimer(for displayID: CGDirectDisplayID) {
        gammaUpdateTimers[displayID]?.invalidate()
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.applyZeroGamma(for: displayID)
        }
        gammaUpdateTimers[displayID] = timer
    }
    
    private func applyZeroGamma(for displayID: CGDirectDisplayID) {
        let zeroTable = [CGGammaValue](repeating: 0, count: 256)
        var runs = 0
        
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            let result = CGSetDisplayTransferByTable(displayID, 256, zeroTable, zeroTable, zeroTable)
            if result == .success {
                print("Successfully applied zero gamma to display \(displayID) (application number \(runs + 1))")
            }
            
            runs += 1
            
            if runs >= 5 {
                print("Applied zero gamma to display \(displayID) \(runs) times")
                timer.invalidate()
                self?.gammaUpdateTimers[displayID] = nil
            }
        }
        
        gammaUpdateTimers[displayID] = timer
    }
}
