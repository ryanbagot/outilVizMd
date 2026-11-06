import Darwin
import Foundation
@preconcurrency import Dispatch

actor DocumentMonitor {
    private struct Observation {
        let token = UUID()
        let handle: DocumentHandle
        let changed: @Sendable (UUID) async -> Void
        var metadata: FileMetadata?
        var sources: [DispatchSourceFileSystemObject] = []
        var debounce: Task<Void, Never>?
    }
    private let access: AuthorizedFileAccess
    private var observations: [UUID: Observation] = [:]
    private var checkClock: UInt64 = 0
    private var latestCheck: [UUID: UInt64] = [:]
    private var epochs: [UUID: UInt64] = [:]
    private var activeID: UUID?
    private var polling: Task<Void, Never>?
    private var refresh = RefreshController()

    init(access: AuthorizedFileAccess) { self.access = access }
    deinit {
        polling?.cancel()
        for observation in observations.values {
            observation.debounce?.cancel()
            observation.sources.forEach { $0.cancel() }
        }
    }

    func start(_ handle: DocumentHandle, changed: @escaping @Sendable (UUID) async -> Void) async {
        if observations[handle.id]?.handle.grantID == handle.grantID { return }
        stop(handle.id)
        let epoch = epochs[handle.id]
        let metadata = try? await access.metadata(handle.location, grantID: handle.grantID)
        guard observations[handle.id] == nil, epochs[handle.id] == epoch else { return }
        let observation = Observation(handle: handle, changed: changed, metadata: metadata)
        observations[handle.id] = observation
        await rearm(handle.id, token: observation.token)
        if polling == nil {
            polling = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
                    await self?.poll()
                }
            }
        }
    }

    func activate(_ id: UUID?) async {
        activeID = id
        if let id { await inspect(id) }
    }

    func stop(_ id: UUID) {
        epochs[id, default: 0] &+= 1
        latestCheck.removeValue(forKey: id)
        guard let observation = observations.removeValue(forKey: id) else { return }
        observation.debounce?.cancel()
        observation.sources.forEach { $0.cancel() }
        refresh.remove(id)
        if activeID == id { activeID = nil }
        if observations.isEmpty { polling?.cancel(); polling = nil }
    }

    private func poll() async { if let activeID { await inspect(activeID) } }

    private func inspect(_ id: UUID) async {
        guard let original = observations[id] else { return }
        checkClock &+= 1
        let check = checkClock
        latestCheck[id] = check
        let metadata = try? await access.metadata(original.handle.location, grantID: original.handle.grantID)
        guard var observation = observations[id], observation.token == original.token, latestCheck[id] == check, observation.metadata != metadata else { return }
        let replaced = observation.metadata?.identity != metadata?.identity
        observation.metadata = metadata
        observation.debounce?.cancel()
        refresh.signal(id, at: Self.now)
        observation.debounce = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            await self?.deliver(id, token: original.token)
        }
        observations[id] = observation
        if replaced { await rearm(id, token: original.token) }
    }

    private func deliver(_ id: UUID, token: UUID) async {
        guard let observation = observations[id], observation.token == token, refresh.isDue(id, at: Self.now) else { return }
        refresh.remove(id)
        await observation.changed(id)
    }

    private func rearm(_ id: UUID, token: UUID) async {
        guard let observation = observations[id], observation.token == token else { return }
        let descriptors = (try? await access.observationDescriptors(observation.handle.location, grantID: observation.handle.grantID)) ?? []
        guard var current = observations[id], current.token == token else { descriptors.forEach { Darwin.close($0) }; return }
        current.sources.forEach { $0.cancel() }
        current.sources = descriptors.map { descriptor in
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .extend, .attrib, .rename, .delete, .revoke], queue: .global(qos: .utility))
            source.setEventHandler { [weak self] in Task { await self?.inspect(id) } }
            source.setCancelHandler { Darwin.close(descriptor) }
            source.resume()
            return source
        }
        observations[id] = current
    }
    private static var now: UInt64 { DispatchTime.now().uptimeNanoseconds / 1_000_000 }
}
