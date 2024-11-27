//
//  DisplayInfoModel.swift
//  BlackoutTest
//
//  Created by Alon Natapov on 26/11/2024.
//

import SwiftUI
import CoreGraphics

class DisplayInfo: ObservableObject, Identifiable {
    let id: CGDirectDisplayID
    let name: String
    @Published var isBlackedOut: Bool = false
    let isPrimary: Bool

    init(id: CGDirectDisplayID, name: String, isBlackedOut: Bool, isPrimary: Bool) {
        self.id = id
        self.name = name
        self.isBlackedOut = isBlackedOut
        self.isPrimary = isPrimary
    }
}
