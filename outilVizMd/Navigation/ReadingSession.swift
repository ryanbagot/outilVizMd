import Foundation

struct ReadingSession: Sendable {
    private(set) var documentIDs: [UUID] = []
    private(set) var activeDocumentID: UUID?

    mutating func open(_ id: UUID) {
        if !documentIDs.contains(id) { documentIDs.append(id) }
        activeDocumentID = id
    }
    mutating func select(_ id: UUID) {
        if documentIDs.contains(id) { activeDocumentID = id }
    }
    mutating func close(_ id: UUID) {
        guard let index = documentIDs.firstIndex(of: id) else { return }
        documentIDs.remove(at: index)
        if activeDocumentID == id {
            activeDocumentID = documentIDs.isEmpty ? nil : documentIDs[min(index, documentIDs.count - 1)]
        }
    }
}
