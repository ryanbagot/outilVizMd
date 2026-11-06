import AppKit
import Foundation
import Observation

/// Les adaptateurs de lecture, analyse et rendu sont injectés lors du branchement du pipeline.
/// Leurs closures asynchrones ne doivent jamais exécuter le travail coûteux sur MainActor.
struct ReadingServices: Sendable {
    let read: @Sendable (DocumentHandle, UInt64) async throws -> DocumentSnapshot
    let parse: @Sendable (DocumentSnapshot) async throws -> ParsedDocument
    let render: @Sendable (ParsedDocument, DocumentHandle, RenderPreferences, PresentationVersion) async throws -> PreviewSnapshot
}

@MainActor
@Observable
final class ReadingCoordinator {
    enum Status: Sendable { case loading, ready, stale, failed }

    struct DocumentState: Sendable {
        var handle: DocumentHandle
        var status: Status
        var snapshot: DocumentSnapshot?
        var preview: PreviewSnapshot?
        var failure: ReaderFailure?
    }

    private(set) var session = ReadingSession()
    var activeDocumentID: UUID? { session.activeDocumentID }
    private(set) var renderedVersions: [UUID: PresentationVersion] = [:]
    private(set) var documents: [UUID: DocumentState] = [:]
    var documentOrder: [UUID] { session.documentIDs }
    private(set) var navigationRoots: [NavigationEntry] = []
    private(set) var expandedDirectories: Set<String> = []
    private(set) var folderGrant: AccessGrant?
    private(set) var isChoosing = false
    var notice: ReaderFailure?
    private(set) var preferences = RenderPreferences.defaults
    private(set) var preferencesWarning: ReaderFailure?
    @ObservationIgnored private let preferencesStore: PreferencesStore?
    @ObservationIgnored private var preferencesRevision: UInt64 = 0
    @ObservationIgnored private var didLoadPreferences = false
    private(set) var isSearchPresented = false
    private(set) var searchQuery = ""
    private(set) var searchState: SearchState?
    @ObservationIgnored private let searchController = SearchController()
    @ObservationIgnored private var queryGeneration: UInt64 = 0
    @ObservationIgnored private var parsedDocuments: [UUID: ParsedDocument] = [:]
    @ObservationIgnored private var gate = GenerationGate()
    @ObservationIgnored private var pendingWork: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored let services: ReadingServices?
    @ObservationIgnored let files: AuthorizedFileAccess
    @ObservationIgnored let broker: AccessBroker
    @ObservationIgnored private let monitor: DocumentMonitor
    @ObservationIgnored private let reader: LocalDocumentReader
    @ObservationIgnored private let parser = MarkdownParser()
    @ObservationIgnored private let renderer: SafeHTMLRenderer
    @ObservationIgnored private let resources = PreviewResourceStore()
    @ObservationIgnored private let controllers = PreviewRegistry()
    @ObservationIgnored private let navigator: DirectoryNavigator
    @ObservationIgnored private var navigationGeneration: UInt64 = 0
    @ObservationIgnored private let openExternal: (URL) -> Void
    @ObservationIgnored private var pendingFragments: [UUID: String] = [:]

    var openDocumentIDs: Set<UUID> { Set(documents.keys) }

    init(services: ReadingServices? = nil, preferencesStore: PreferencesStore? = nil, openExternal: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }) {
        self.openExternal = openExternal
        self.preferencesStore = preferencesStore
        self.services = services
        let files = AuthorizedFileAccess()
        self.files = files
        monitor = DocumentMonitor(access: files)
        broker = AccessBroker(files: files)
        reader = LocalDocumentReader(access: files)
        renderer = SafeHTMLRenderer(access: files)
        navigator = DirectoryNavigator(access: files)
    }

    @discardableResult
    func beginLoading(_ handle: DocumentHandle) throws -> PresentationVersion {
        notice = nil
        let version = try gate.beginSource(for: handle.id)
        pendingWork.removeValue(forKey: handle.id)?.cancel()
        var state = documents[handle.id] ?? DocumentState(handle: handle, status: .loading)
        state.handle = handle
        state.status = .loading
        state.failure = nil
        documents[handle.id] = state
        if !session.documentIDs.contains(handle.id) { session.open(handle.id) }
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
        state.handle = DocumentHandle(id: state.handle.id, location: state.handle.location, identity: snapshot.metadataAfter.identity, grantID: state.handle.grantID)
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
        if activeDocumentID == documentID { closeSearch() }
        parsedDocuments.removeValue(forKey: documentID)
        gate.close(documentID)
        pendingWork.removeValue(forKey: documentID)?.cancel()
        renderedVersions.removeValue(forKey: documentID)
        controllers.remove(documentID)
        Task { await monitor.stop(documentID); await monitor.activate(activeDocumentID) }
        let handle = documents.removeValue(forKey: documentID)?.handle
        session.close(documentID)
        pendingFragments.removeValue(forKey: documentID)
        if let handle { Task { await broker.release(handle.grantID) } }
    }

    func controller(for id: UUID) -> PreviewController? { controllers.get(id) }

    func select(_ id: UUID) {
        guard documents[id] != nil, activeDocumentID != id else { return }
        closeSearch()
        session.select(id)
        if let state = documents[id], state.status == .stale { load(state.handle) }
        else if var state = documents[id], let snapshot = state.snapshot {
            state.status = .loading
            documents[id] = state
            Task {
                do {
                    let metadata = try await files.metadata(state.handle.location, grantID: state.handle.grantID)
                    guard var current = documents[id], current.snapshot?.generation == snapshot.generation else { return }
                    if metadata == snapshot.metadataAfter { current.status = .ready; documents[id] = current }
                    else { load(current.handle) }
                } catch {
                    guard var current = documents[id] else { return }
                    current.status = .stale
                    current.failure = (error as? ReaderFailure) ?? AuthorizedFileAccess.denied
                    documents[id] = current
                }
            }
        }
        Task { await monitor.activate(id) }
    }

    func chooseFile() async {
        guard !isChoosing else { return }
        isChoosing = true
        defer { isChoosing = false }
        do {
            guard let chosen = try await broker.choose(.file) else { return }
            let url = chosen.resolvedRoot
            if let folderGrant, (try? await files.handle(for: url, grantID: folderGrant.id)) != nil {
                try await files.retain(folderGrant.id)
                await broker.release(chosen.id)
                await open(url, grantID: folderGrant.id)
            } else { await open(url, grantID: chosen.id) }
        } catch { show(error) }
    }

    func chooseFolder() async {
        guard !isChoosing else { return }
        isChoosing = true
        defer { isChoosing = false }
        do {
            guard let chosen = try await broker.choose(.directory) else { return }
            try await openFolder(chosen)
        } catch { show(error) }
    }

    /// Traite un choix explicite déjà autorisé ; l’appelant transfère son usage du grant.
    func openFolder(_ chosen: AccessGrant) async throws {
        let old = folderGrant
        folderGrant = chosen
        expandedDirectories.removeAll()
        navigationRoots.removeAll()
        await refreshDirectory()
        if let old { await broker.release(old.id) }
        // Un nouveau choix explicite de dossier peut autoriser les images d’un document ouvert.
        for id in documentOrder {
            guard let state = documents[id], let new = try? await files.handle(for: state.handle.location, grantID: chosen.id) else { continue }
            try await files.retain(chosen.id)
            await broker.release(state.handle.grantID)
            load(DocumentHandle(id: id, location: new.location, identity: new.identity, grantID: chosen.id))
    }
    }

    /// L’appelant transfère une référence du grant ; les doublons la libèrent sans ouvrir une entrée.
    func open(_ url: URL, grantID: UUID, fragment: String? = nil) async {
        do {
            let handle = try await files.handle(for: url, grantID: grantID)
            if let existing = documents.values.first(where: { $0.handle.identity == handle.identity || $0.handle.location == handle.location }) {
                select(existing.handle.id)
                if let fragment { controllers.get(existing.handle.id)?.jump(to: fragment) }
                await broker.release(grantID)
                return
            }
            if let fragment { pendingFragments[handle.id] = fragment }
            load(handle)
        } catch {
            await broker.release(grantID)
            show(error)
        }
    }

    func refreshActive() {
        if let id = activeDocumentID, let state = documents[id] { load(state.handle) }
    }

    private func load(_ handle: DocumentHandle) {
        if pendingFragments[handle.id] == nil, searchQuery.isEmpty { pendingFragments[handle.id] = controllers.get(handle.id)?.semanticFragment }
        if activeDocumentID != handle.id { closeSearch() }
        do {
            let version = try beginLoading(handle)
            let prefs = preferences
            let task = Task { [weak self] in
                guard let self else { return }
                await monitor.start(handle) { [weak self] id in await self?.externalChange(id) }
                await monitor.activate(activeDocumentID)
                guard accepts(version) else { return }
                do {
                    let snapshot: DocumentSnapshot
                    let parsed: ParsedDocument
                    var preview: PreviewSnapshot
                    if let services {
                        snapshot = try await services.read(handle, version.sourceGeneration)
                        guard accepts(version) else { return }
                        parsed = try await services.parse(snapshot)
                        guard accepts(version) else { return }
                        preview = try await services.render(parsed, handle, prefs, version)
                    } else {
                        snapshot = try await reader.read(handle: handle, generation: version.sourceGeneration)
                        guard accepts(version) else { return }
                        parsed = await parser.parse(snapshot)
                        guard accepts(version) else { return }
                        preview = try await renderer.render(parsed, documentURL: handle.location, grantID: handle.grantID, preferences: prefs, version: version)
                    }
                    guard accepts(version) else { return }
                    let query = activeDocumentID == handle.id && isSearchPresented ? searchQuery : ""
                    let qgen = queryGeneration
                    if !query.isEmpty, let projection = preview.visibleText {
                        let found = await searchController.search(query, projection: projection, documentID: handle.id, sourceGeneration: version.sourceGeneration, queryGeneration: qgen)
                        guard accepts(version) else { return }
                        guard queryGeneration == qgen else { load(handle); return }
                        searchState = found
                        preview = try await renderer.render(parsed, documentURL: handle.location, grantID: handle.grantID, preferences: prefs, version: version, search: found, reusing: preview)
                    }
                    guard accepts(version) else { return }
                    parsedDocuments[handle.id] = parsed
                    let controller: PreviewController
                    if let existing = controllers.get(handle.id) { controller = existing }
                    else {
                        controller = try await PreviewController.make(store: resources)
                        guard accepts(version) else { controller.close(); return }
                        controllers.set(controller, for: handle.id)
                    }
                    controller.onReady = { [weak self] rendered in
                        guard let self, accepts(rendered) else { return }
                        renderedVersions[rendered.documentID] = rendered
                    }
                    controller.onNavigation = { [weak self] decision in self?.navigate(decision) }
                    controller.onFailure = { [weak self] failure in
                        guard let self, documents[handle.id] != nil else { return }
                        notice = failure
                    }
                    if publish(snapshot, preview: preview, for: version) { controller.load(preview, fragment: pendingFragments.removeValue(forKey: handle.id) ?? (activeDocumentID == handle.id ? searchState?.fragment : nil)) }
                } catch is CancellationError { }
                catch {
                    let failure = (error as? ReaderFailure) ?? ReaderFailure(category: .renderingFailed, message: "Le document n’a pas pu être affiché. Réessayez ou choisissez un autre fichier.", recoveries: [.retry, .selectFile, .close], documentID: handle.id)
                    _ = publishFailure(failure, for: version)
                }
            }
            retainWork(task, for: handle.id)
        } catch { show(error) }
    }

    func reactivate() { Task { await monitor.activate(activeDocumentID) } }

    private func externalChange(_ id: UUID) async {
        guard let original = documents[id] else { return }
        let metadata = try? await files.metadata(original.handle.location, grantID: original.handle.grantID)
        guard var state = documents[id] else { return }
        // Une notification n’est pas une preuve de changement : comparer à la
        // dernière version publiée, y compris après un await ou une bascule.
        if let metadata, metadata == state.snapshot?.metadataAfter {
            if state.status == .stale { state.status = .ready; state.failure = nil; documents[id] = state }
            return
        }
        if activeDocumentID == id { load(state.handle) }
        else {
            state.status = .stale
            state.failure = ReaderFailure(category: .unstableRead, message: "Le document a changé. Son aperçu sera revérifié à l’ouverture.", recoveries: [.retry, .close], documentID: id)
            documents[id] = state
        }
    }

    func loadPreferences() async {
        guard !didLoadPreferences, let preferencesStore else { return }
        didLoadPreferences = true
        let revision = preferencesRevision
        let loaded = await preferencesStore.load()
        guard preferencesRevision == revision else { return }
        preferences = loaded.preferences
        preferencesWarning = loaded.warning
        for id in documentOrder { refreshPresentation(id) }
    }

    func updatePreferences(_ prefs: RenderPreferences) {
        preferences = prefs
        preferencesRevision &+= 1
        let revision = preferencesRevision
        for id in documentOrder {
            if let state = documents[id], state.status == .loading { load(state.handle) }
            else { refreshPresentation(id, selectedIndex: searchState?.currentIndex) }
        }
        guard let preferencesStore else { return }
        Task { [weak self] in
            do {
                try await preferencesStore.save(prefs, revision: revision)
                if self?.preferencesRevision == revision { self?.preferencesWarning = nil }
            } catch {
                if self?.preferencesRevision == revision { self?.preferencesWarning = PreferencesStore.notSaved }
            }
        }
    }

    func resetPreferences() { updatePreferences(.defaults) }

    func presentSearch() { if activeDocumentID != nil { isSearchPresented = true } }

    func updateSearch(_ query: String) {
        searchQuery = query
        queryGeneration &+= 1
        searchState = nil
        if let id = activeDocumentID { refreshPresentation(id) }
    }

    func closeSearch() {
        let hadMarks = !searchQuery.isEmpty
        isSearchPresented = false
        searchQuery = ""
        searchState = nil
        queryGeneration &+= 1
        if hadMarks, let id = activeDocumentID { refreshPresentation(id) }
    }

    func moveSearch(_ direction: Int) {
        guard var state = searchState, let id = activeDocumentID else { return }
        state.advance(direction)
        searchState = state
        refreshPresentation(id, selectedIndex: state.currentIndex)
    }

    func refreshPresentation(_ id: UUID, selectedIndex: Int? = nil) {
        guard let document = documents[id], document.status != .loading,
              let parsed = parsedDocuments[id], let snapshot = document.snapshot,
              parsed.snapshotGeneration == snapshot.generation else { return }
        do {
            let version = try beginPresentation(for: id)
            let prefs = preferences
            let query = id == activeDocumentID && isSearchPresented ? searchQuery : ""
            let qgen = queryGeneration
            let previous = document.preview
            let task = Task { [weak self] in
                guard let self else { return }
                do {
                    var found: SearchState?
                    if let projection = previous?.visibleText, !query.isEmpty {
                        var state = await searchController.search(query, projection: projection, documentID: id, sourceGeneration: version.sourceGeneration, queryGeneration: qgen)
                        guard accepts(version), queryGeneration == qgen else { return }
                        if let selectedIndex, state.total > 0 { state.currentIndex = min(selectedIndex, state.total - 1) }
                        found = state
                    }
                    guard accepts(version), queryGeneration == qgen else { return }
                    if id == activeDocumentID { searchState = found }
                    let preview = try await renderer.render(parsed, documentURL: document.handle.location, grantID: document.handle.grantID, preferences: prefs, version: version, search: found, reusing: previous)
                    guard accepts(version), queryGeneration == qgen else { return }
                    if id == activeDocumentID { searchState = found }
                    if publish(snapshot, preview: preview, for: version) {
                        controllers.get(id)?.load(preview, fragment: found?.fragment)
                    }
                } catch is CancellationError { }
                catch { if accepts(version) { show(error) } }
            }
            retainWork(task, for: id)
        } catch { show(error) }
    }

    func navigate(_ decision: PreviewNavigation) {
        switch decision {
        case let .openExternal(url):
            guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil, url.user == nil, url.password == nil else { return }
            openExternal(url)
        case let .openLocal(url):
            Task {
                do {
                    let link = try await LocalLinkRouter(access: files).resolve(url)
                    try await files.retain(link.grantID)
                    await open(link.url, grantID: link.grantID, fragment: link.fragment)
                }
                catch { show(error) }
            }
        default: break
        }
    }

    private func show(_ error: Error) {
        notice = (error as? ReaderFailure) ?? ReaderFailure(category: .accessDenied, message: "Le document est indisponible. Sélectionnez-le à nouveau.", recoveries: [.selectFile, .selectFolder], documentID: nil)
    }

    func refreshDirectory() async {
        guard let grant = folderGrant else { return }
        navigationGeneration &+= 1
        let generation = navigationGeneration
        let expanded = expandedDirectories
        do {
            let roots = try await navigator.entries(at: grant.resolvedRoot, grantID: grant.id)
            guard folderGrant?.id == grant.id, navigationGeneration == generation else { return }
            navigationRoots = roots
            expandedDirectories.removeAll()
            for path in expanded.sorted(by: { $0.split(separator: "/").count < $1.split(separator: "/").count }) {
                if findEntry(path, in: navigationRoots) != nil { await expandDirectory(path) }
            }
        } catch { if folderGrant?.id == grant.id { show(error) } }
    }

    func toggleDirectory(_ id: String) {
        if expandedDirectories.contains(id) { expandedDirectories.remove(id) }
        else { Task { await expandDirectory(id) } }
    }

    private func expandDirectory(_ id: String) async {
        guard let entry = findEntry(id, in: navigationRoots), entry.kind == .directory, let grant = folderGrant else { return }
        expandedDirectories.insert(id)
        guard entry.children == nil else { return }
        let generation = navigationGeneration
        do {
            let children = try await navigator.entries(at: entry.url, grantID: grant.id)
            guard folderGrant?.id == grant.id, navigationGeneration == generation else { return }
            updateEntry(id, entries: &navigationRoots) { $0.children = children; $0.failure = nil }
        } catch {
            guard folderGrant?.id == grant.id, navigationGeneration == generation else { return }
            updateEntry(id, entries: &navigationRoots) { $0.failure = AuthorizedFileAccess.denied }
        }
    }

    func openDirectoryDocument(_ entry: NavigationEntry) async {
        guard let grant = folderGrant, entry.kind == .document else { return }
        do { try await files.retain(grant.id); await open(entry.url, grantID: grant.id) }
        catch { show(error) }
    }

    private func findEntry(_ id: String, in entries: [NavigationEntry]) -> NavigationEntry? {
        for entry in entries {
            if entry.id == id { return entry }
            if let children = entry.children, let found = findEntry(id, in: children) { return found }
        }
        return nil
    }

    private func updateEntry(_ id: String, entries: inout [NavigationEntry], update: (inout NavigationEntry) -> Void) {
        for index in entries.indices {
            if entries[index].id == id { update(&entries[index]); return }
            if var children = entries[index].children {
                updateEntry(id, entries: &children, update: update)
                entries[index].children = children
            }
        }
    }
}
