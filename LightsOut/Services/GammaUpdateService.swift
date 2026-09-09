import CoreGraphics
import Foundation

/// All calls run on the main thread. Recovery cancels every retry before restoring color.
final class GammaUpdateService {
    private var timers: [CGDirectDisplayID: Timer] = [:]
    private let writeBlackout: (CGDirectDisplayID) -> Bool
    private let restoreColor: () -> Void

    init(writeBlackout: @escaping (CGDirectDisplayID) -> Bool = { id in
        let zero = [CGGammaValue](repeating: 0, count: 256)
        return CGSetDisplayTransferByTable(id, 256, zero, zero, zero) == .success
    }, restoreColor: @escaping () -> Void = { CGDisplayRestoreColorSyncSettings() }) {
        self.writeBlackout = writeBlackout
        self.restoreColor = restoreColor
    }

    var canBlackout: ((CGDirectDisplayID) -> Bool)?
    var onFailure: (() -> Void)?

    func setZeroGamma(for display: DisplayInfo) throws(DisplayError) {
        cancel(for: display.id)
        guard applyBlackout(display.id) else {
            throw DisplayError(msg: "Cannot safely darken '\(display.name)'.")
        }
        display.state = .mirrored
        var remaining = 4
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            guard display.state == .mirrored, self.applyBlackout(display.id) else {
                self.cancel(for: display.id)
                self.onFailure?()
                return
            }
            remaining -= 1
            if remaining == 0 { self.cancel(for: display.id) }
        }
        timers[display.id] = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func applyBlackout(_ id: CGDirectDisplayID) -> Bool {
        guard canBlackout?(id) == true else { return false }
        return writeBlackout(id)
    }

    private func cancel(for id: CGDirectDisplayID) {
        timers.removeValue(forKey: id)?.invalidate()
    }

    func restoreGamma(for display: DisplayInfo) {
        // ColorSync restoration is global; stop all pending writes first.
        restoreAll()
    }

    func restoreAll() {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
        restoreColor()
    }

    deinit { timers.values.forEach { $0.invalidate() } }
}
