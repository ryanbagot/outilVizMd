import Foundation

/// Débattement monotone testable avec une horloge contrôlée (millisecondes).
struct RefreshController: Sendable {
    private var signals: [UUID: UInt64] = [:]
    mutating func signal(_ id: UUID, at milliseconds: UInt64) { signals[id] = milliseconds }
    func isDue(_ id: UUID, at milliseconds: UInt64) -> Bool {
        guard let last = signals[id], milliseconds >= last else { return false }
        return milliseconds - last >= 150
    }
    mutating func remove(_ id: UUID) { signals.removeValue(forKey: id) }
}
