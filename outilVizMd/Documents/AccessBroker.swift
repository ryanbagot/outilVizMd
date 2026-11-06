import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AccessBroker {
    let files: AuthorizedFileAccess
    private var scopes: [UUID: (url: URL, acquired: Bool)] = [:]

    init(files: AuthorizedFileAccess) { self.files = files }

    deinit {
        for scope in scopes.values where scope.acquired { scope.url.stopAccessingSecurityScopedResource() }
    }

    func choose(_ kind: AccessGrant.Kind) async throws -> AccessGrant? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = kind == .directory
        panel.canChooseFiles = kind == .file
        panel.allowsMultipleSelection = false
        panel.prompt = kind == .directory ? "Choisir ce dossier" : "Ouvrir"
        if kind == .file { panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText, UTType(filenameExtension: "markdown") ?? .plainText] }
        let result = await withCheckedContinuation { continuation in
            panel.begin { continuation.resume(returning: $0) }
        }
        guard result == .OK, let url = panel.url else { return nil }
        let acquired = url.startAccessingSecurityScopedResource()
        do {
            let grant = try await files.authorizeSelectedURL(url, kind: kind)
            scopes[grant.id] = (url, acquired)
            return grant
        } catch {
            if acquired { url.stopAccessingSecurityScopedResource() }
            throw error
        }
    }

    func release(_ id: UUID) async {
        if await files.release(id), let scope = scopes.removeValue(forKey: id), scope.acquired {
            scope.url.stopAccessingSecurityScopedResource()
        }
    }
}
