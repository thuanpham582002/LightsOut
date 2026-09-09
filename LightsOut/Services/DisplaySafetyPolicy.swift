import Foundation

enum DisplaySafetyPolicy {
    static func needsRecovery(visible: Set<UInt32>, anchors: Set<UInt32>) -> Bool {
        // Fail open on loss of any monitor that made a blackout safe, even if
        // another monitor survives a dock/cable topology change.
        visible.isEmpty || !anchors.isSubset(of: visible)
    }
}
