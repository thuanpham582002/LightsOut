//
//  GammaUpdateService.swift
//  BlackoutTest

import CoreGraphics
import SwiftUI

class GammaUpdateService {
    @Published var originalGammaTables: [CGDirectDisplayID: (red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue])] = [:]
    private var gammaUpdateTimers: [DisplayInfo: Timer] = [:]
    
    func setZeroGamma(for display: DisplayInfo) {
        saveOriginalGamma(for: display.id)
        applyZeroGamma(for: display)
    }
    
    func restoreGamma(for display: DisplayInfo) {
        gammaUpdateTimers[display]?.invalidate()
        gammaUpdateTimers[display] = nil
        
        if let originalTables = originalGammaTables[display.id] {
            CGSetDisplayTransferByTable(display.id, UInt32(originalTables.red.count), originalTables.red, originalTables.green, originalTables.blue)
        } else {
            print("No original gamma table saved for display \(display.name).")
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
    
    private func applyZeroGamma(for display: DisplayInfo) {
        let zeroTable = [CGGammaValue](repeating: 0, count: 256)
        var runs = 0
        
        display.state = .pending
        printmem(of: display)

        print(display.state)
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            let result = CGSetDisplayTransferByTable(display.id, 256, zeroTable, zeroTable, zeroTable)
            if result == .success {
                print("Successfully applied zero gamma to display \(display.id) (application number \(runs + 1))")
            }
            
            runs += 1
            
            if runs >= 5 {
                print("Applied zero gamma to display \(display.id) \(runs) times")
                timer.invalidate()
                self?.gammaUpdateTimers[display] = nil
                display.state = .softDisabled
            }
        }
        
        gammaUpdateTimers[display] = timer
    }
}
