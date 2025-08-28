//
//  ConfigurationError.swift
//  LightsOut
//
//

import Foundation
import CoreGraphics

struct DisplayError: Error, Identifiable {
    var id: String { UUID().uuidString }
    var msg: String
    
    // MARK: - Common Error Cases
    
    static let unknownError = DisplayError(msg: "Unknown error occurred")
}
