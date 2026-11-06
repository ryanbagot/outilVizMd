import Foundation

/// Une horloge de session empêche qu’un identifiant fermé puis rouvert réaccepte un vieux ticket.
/// La valeur est confinée au coordinateur MainActor ; aucune publication ne dépend de cancel().
struct GenerationGate: Sendable {
    enum Failure: Error { case documentClosed, generationExhausted }

    private var clock: UInt64 = 0
    private var expected: [UUID: PresentationVersion] = [:]

    mutating func beginSource(for documentID: UUID) throws -> PresentationVersion {
        let next = try tick()
        let version = PresentationVersion(documentID: documentID,
                                          sourceGeneration: next,
                                          presentationGeneration: next)
        expected[documentID] = version
        return version
    }

    mutating func beginPresentation(for documentID: UUID) throws -> PresentationVersion {
        guard let source = expected[documentID] else { throw Failure.documentClosed }
        let version = PresentationVersion(documentID: documentID,
                                          sourceGeneration: source.sourceGeneration,
                                          presentationGeneration: try tick())
        expected[documentID] = version
        return version
    }

    func accepts(_ version: PresentationVersion) -> Bool {
        expected[version.documentID] == version
    }

    func canDisplay(_ version: PresentationVersion, activeDocumentID: UUID?) -> Bool {
        version.documentID == activeDocumentID && accepts(version)
    }

    mutating func close(_ documentID: UUID) {
        expected.removeValue(forKey: documentID)
    }

    private mutating func tick() throws -> UInt64 {
        guard clock < UInt64.max else { throw Failure.generationExhausted }
        clock += 1
        return clock
    }
}
