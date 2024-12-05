//
//  DisplayInfoModel.swift
//  BlackoutTest


import SwiftUI
import CoreGraphics

enum DisplayState {
    case softDisabled
    case hardDisabled
    case pending
    case active
    
    func isEnabled() -> Bool {
        switch self {
        case .softDisabled, .hardDisabled:
            return false
        default:
            return true
        }
    }
}

class DisplayInfo: ObservableObject, Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    @Published var state: DisplayState
    let isPrimary: Bool

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
