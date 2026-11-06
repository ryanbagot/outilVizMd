import Foundation

@MainActor
final class PreviewResourceStore {
    private var previews: [UUID: PreviewSnapshot] = [:]

    func install(_ snapshot: PreviewSnapshot) { previews[snapshot.token] = snapshot }
    func revoke(_ token: UUID) { previews.removeValue(forKey: token) }

    func resource(for url: URL) throws -> ResourceSnapshot {
        guard let parts = Self.parts(url), let token = UUID(uuidString: parts[0]), let preview = previews[token] else { throw Self.unavailable }
        if parts.count == 2, parts[1] == "document" {
            return ResourceSnapshot(id: token, previewToken: token, bytes: preview.htmlData, mime: .html, pixelWidth: nil, pixelHeight: nil, alternativeText: "")
        }
        guard parts.count == 3, parts[1] == "resource", let id = UUID(uuidString: parts[2]),
              let resource = preview.resources.first(where: { $0.id == id && $0.previewToken == token }),
              resource.mime == .png || resource.mime == .jpeg else { throw Self.unavailable }
        return resource
    }

    nonisolated static func parts(_ url: URL) -> [String]? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "outilvizmd", components.host == "preview", components.port == nil,
              components.user == nil, components.password == nil, components.query == nil,
              !components.percentEncodedPath.contains("%"), !components.path.contains("//") else { return nil }
        let parts = components.path.split(separator: "/").map(String.init)
        guard (2...3).contains(parts.count), !parts.contains("."), !parts.contains(".."), components.path == "/" + parts.joined(separator: "/") else { return nil }
        return parts
    }
    static let unavailable = ReaderFailure(category: .resourceUnavailable, message: "Cette ressource de l’aperçu n’est plus disponible.", recoveries: [.retry], documentID: nil)
}
