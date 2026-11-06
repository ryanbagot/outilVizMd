import Foundation
import Observation

/// Les adaptateurs de lecture, analyse et rendu sont injectés lors du branchement du pipeline.
/// Leurs closures asynchrones ne doivent jamais exécuter le travail coûteux sur MainActor.
struct ReadingServices: Sendable {
    let read: @Sendable (DocumentHandle, UInt64) async throws -> DocumentSnapshot
    let parse: @Sendable (DocumentSnapshot) async throws -> ParsedDocument
    let render: @Sendable (ParsedDocument, RenderPreferences, PresentationVersion) async throws -> PreviewSnapshot
}

@MainActor
@Observable
final class ReadingCoordinator {
    enum Status: Sendable { case loading, ready, stale, failed }

    struct DocumentState: Sendable {
        let handle: DocumentHandle
        var status: Status
        var snapshot: DocumentSnapshot?
        var preview: PreviewSnapshot?
        var failure: ReaderFailure?
    }

    private(set) var activeDocumentID: UUID?
    private(set) var documents: [UUID: DocumentState] = [:]
    @ObservationIgnored private var gate = GenerationGate()
    @ObservationIgnored private var pendingWork: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored let services: ReadingServices?

    var openDocumentIDs: Set<UUID> { Set(documents.keys) }

    init(services: ReadingServices? = nil) {
        self.services = services
    }

    @discardableResult
    func beginLoading(_ handle: DocumentHandle) throws -> PresentationVersion {
        let version = try gate.beginSource(for: handle.id)
        pendingWork.removeValue(forKey: handle.id)?.cancel()
        var state = documents[handle.id] ?? DocumentState(handle: handle, status: .loading)
        state.status = .loading
        state.failure = nil
        documents[handle.id] = state
        activeDocumentID = handle.id
        return version
    }

    func beginPresentation(for documentID: UUID) throws -> PresentationVersion {
        try gate.beginPresentation(for: documentID)
    }

    func accepts(_ version: PresentationVersion) -> Bool {
        documents[version.documentID] != nil && gate.accepts(version)
    }

    func canDisplay(_ version: PresentationVersion) -> Bool {
        accepts(version) && gate.canDisplay(version, activeDocumentID: activeDocumentID)
    }

    @discardableResult
    func publish(_ snapshot: DocumentSnapshot, preview: PreviewSnapshot,
                 for version: PresentationVersion) -> Bool {
        guard accepts(version), snapshot.documentID == version.documentID,
              snapshot.generation == version.sourceGeneration,
              preview.version == version, var state = documents[version.documentID] else { return false }
        state.snapshot = snapshot
        state.preview = preview
        state.status = .ready
        state.failure = nil
        documents[version.documentID] = state
        return true
    }

    @discardableResult
    func publishFailure(_ failure: ReaderFailure, for version: PresentationVersion) -> Bool {
        guard accepts(version), var state = documents[version.documentID] else { return false }
        state.status = state.preview == nil ? .failed : .stale
        state.failure = failure
        documents[version.documentID] = state
        return true
    }

    func retainWork(_ task: Task<Void, Never>, for documentID: UUID) {
        guard documents[documentID] != nil else { task.cancel(); return }
        pendingWork.removeValue(forKey: documentID)?.cancel()
        pendingWork[documentID] = task
    }

    func close(_ documentID: UUID) {
        gate.close(documentID)
        pendingWork.removeValue(forKey: documentID)?.cancel()
        documents.removeValue(forKey: documentID)
        if activeDocumentID == documentID { activeDocumentID = nil }
        // Le choix du prochain actif, les vues et grants seront branchés dans les tranches US1/US2.
    }
}
