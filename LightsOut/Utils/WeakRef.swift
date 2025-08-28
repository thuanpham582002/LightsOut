//
//  WeakRef.swift
//  LightsOut
//
//  Weak reference wrapper to prevent retain cycles in display mirroring
//

import Foundation

/// Weak reference wrapper for objects
class WeakRef<T: AnyObject> {
    weak var value: T?
    
    init(_ value: T?) {
        self.value = value
    }
}

extension WeakRef: Equatable where T: Equatable {
    static func == (lhs: WeakRef<T>, rhs: WeakRef<T>) -> Bool {
        return lhs.value == rhs.value
    }
}

extension WeakRef: Hashable where T: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

/// Array extension for easier weak reference management
extension Array where Element: AnyObject {
    /// Convert strong reference array to weak reference array
    var weakRefs: [WeakRef<Element>] {
        return self.map { WeakRef($0) }
    }
}

extension Array where Element == WeakRef<DisplayInfo> {
    /// Get all valid (non-nil) display references
    var validDisplays: [DisplayInfo] {
        return self.compactMap { $0.value }
    }
    
    /// Remove nil/deallocated references
    mutating func removeNilReferences() {
        self = self.filter { $0.value != nil }
    }
    
    /// Add a display with weak reference (avoiding duplicates)
    mutating func addDisplayWeakly(_ display: DisplayInfo) {
        // Remove existing reference to same display (by ID)
        self.removeAll { $0.value?.id == display.id }
        // Add new weak reference
        self.append(WeakRef(display))
    }
    
    /// Remove a display by ID
    mutating func removeDisplay(withID displayID: CGDirectDisplayID) {
        self.removeAll { $0.value?.id == displayID }
    }
}