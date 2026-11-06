import Foundation

struct ResolvedLocalLink: Sendable {
    let url: URL
    let grantID: UUID
    let fragment: String?
}

struct LocalLinkRouter: Sendable {
    let access: AuthorizedFileAccess

    func resolve(_ target: URL) async throws -> ResolvedLocalLink {
        guard target.isFileURL, var parts = URLComponents(url: target, resolvingAgainstBaseURL: false), parts.query == nil else { throw AuthorizedFileAccess.denied }
        let fragment = parts.fragment
        parts.fragment = nil
        guard let file = parts.url, ["md", "markdown"].contains(file.pathExtension.lowercased()),
              let grant = await access.matchingGrant(for: file) else { throw AuthorizedFileAccess.denied }
        return ResolvedLocalLink(url: file, grantID: grant.id, fragment: fragment)
    }
}
