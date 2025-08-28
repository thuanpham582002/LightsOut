//
//  DisplayInfoModel.swift
//  BlackoutTest


import SwiftUI
import CoreGraphics

enum DisplayState {
    case mirrored
    case disconnected
    case pending
    case active
    
    func isOff() -> Bool {
        switch self {
        case .mirrored, .disconnected:
            return true
        default:
            return false
        }
    }
}

class DisplayInfo: ObservableObject, Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    var isPrimary: Bool
    @Published var state: DisplayState {
        didSet {
            print("Display '\(name)' changed state to '\(state)'")
        }
    }
    
    // 🔧 MEMORY LEAK FIX: Use weak references to prevent retain cycles
    private var _mirroredTo: [WeakRef<DisplayInfo>] = []
    weak var mirrorSource: DisplayInfo? // Weak reference to prevent cycles

    init(id: CGDirectDisplayID, name: String, state: DisplayState, isPrimary: Bool) {
        self.id = id
        self.name = name
        self.state = state
        self.isPrimary = isPrimary
    }
    
    // 🔧 SAFE ACCESS: Computed properties for mirrored displays
    var mirroredTo: [DisplayInfo] {
        get {
            // Clean up nil references and return valid displays
            _mirroredTo.removeNilReferences()
            return _mirroredTo.validDisplays
        }
        set {
            _mirroredTo = newValue.weakRefs
        }
    }
    
    /// Add a display to mirror list (with weak reference)
    func addMirroredDisplay(_ display: DisplayInfo) {
        _mirroredTo.addDisplayWeakly(display)
        display.mirrorSource = self
        print("🪞 \(display.name) is now mirrored to \(self.name)")
    }
    
    /// Remove a display from mirror list
    func removeMirroredDisplay(_ display: DisplayInfo) {
        _mirroredTo.removeDisplay(withID: display.id)
        display.mirrorSource = nil
        print("🪞 \(display.name) is no longer mirrored to \(self.name)")
    }
    
    /// Clean up all mirror relationships
    func cleanupMirrorRelationships() {
        print("🧹 Cleaning up mirror relationships for \(name)")
        
        // Clear outgoing relationships (displays mirrored to this one)
        let currentMirroredDisplays = mirroredTo
        for display in currentMirroredDisplays {
            removeMirroredDisplay(display)
        }
        
        // Clear incoming relationship (if this display is mirrored to another)
        if let source = mirrorSource {
            source.removeMirroredDisplay(self)
        }
        
        _mirroredTo.removeAll()
        mirrorSource = nil
        
        print("✅ Mirror relationships cleaned up for \(name)")
    }
    
    deinit {
        print("♻️ DisplayInfo \(name) is being deallocated")
        cleanupMirrorRelationships()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DisplayInfo, rhs: DisplayInfo) -> Bool {
        return lhs.id == rhs.id
    }
}
