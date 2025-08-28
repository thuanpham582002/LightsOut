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
    
    /// Creates a DisplayError for built-in display protection
    static func builtInDisplayProtection(_ reason: String) -> DisplayError {
        return DisplayError(msg: "🛡️ Built-in Display Protection: \(reason)")
    }
}
