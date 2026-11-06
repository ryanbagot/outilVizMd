import Foundation

struct SearchState: Sendable {
    let documentID: UUID
    let sourceGeneration: UInt64
    let queryGeneration: UInt64
    let query: String
    let matches: [SearchMatch]
    var currentIndex: Int
    var total: Int { matches.count }
    var fragment: String? { matches.isEmpty ? nil : "search-\(currentIndex)" }
    var counter: String { matches.isEmpty ? "Aucun résultat" : "\(currentIndex + 1) sur \(total)" }
    mutating func advance(_ direction: Int) {
        guard total > 0 else { return }
        currentIndex = (currentIndex + direction % total + total) % total
    }
}
