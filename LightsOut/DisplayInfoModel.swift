//
//  DisplayInfoModel.swift
//  BlackoutTest


import SwiftUI
import CoreGraphics

enum DisplayState {
    case disabled
    case disconnected
    case pending
    case active
    
    func isOff() -> Bool {
        switch self {
        case .disabled, .disconnected:
            return true
        default:
            return false
        }
    }
}

class DisplayInfo: ObservableObject, Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    let isPrimary: Bool
    @Published var state: DisplayState {
        didSet {
            print("Display '\(name)' changed state to '\(state)'")
        }
    }

    init(id: CGDirectDisplayID, name: String, state: DisplayState, isPrimary: Bool) {
        self.id = id
        self.name = name
        self.state = state
        self.isPrimary = isPrimary
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DisplayInfo, rhs: DisplayInfo) -> Bool {
        return lhs.id == rhs.id
    }
}
