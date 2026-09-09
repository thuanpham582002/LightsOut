//
//  DisplayInfoModel.swift
//  BlackoutTest


import SwiftUI
import CoreGraphics

enum DisplayState: String, Codable {
    case mirrored
    case disconnected
    case pending
    case active
    case unavailable
    
    func isOff() -> Bool {
        switch self {
        case .mirrored, .disconnected, .unavailable:
            return true
        default:
            return false
        }
    }
}

class DisplayInfo: ObservableObject, Identifiable, Hashable {
    let id: CGDirectDisplayID
    @Published var name: String
    var uuid: String?
    var isBuiltIn: Bool
    var isManagedDisabled = false
    @Published var statusMessage: String?
    var isPrimary: Bool
    @Published var state: DisplayState {
        didSet {
            print("Display '\(name)' changed state to '\(state)'")
        }
    }
    var mirroredTo: [DisplayInfo] = []
    var mirrorSource: DisplayInfo?

    init(id: CGDirectDisplayID, name: String, state: DisplayState, isPrimary: Bool,
         uuid: String? = nil, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.state = state
        self.isPrimary = isPrimary
        self.uuid = uuid
        self.isBuiltIn = isBuiltIn
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DisplayInfo, rhs: DisplayInfo) -> Bool {
        return lhs.id == rhs.id
    }
}
