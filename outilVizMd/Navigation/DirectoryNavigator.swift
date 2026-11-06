import Foundation

actor DirectoryNavigator {
    let access: AuthorizedFileAccess
    init(access: AuthorizedFileAccess) { self.access = access }

    func entries(at url: URL, grantID: UUID) async throws -> [NavigationEntry] {
        try await access.listDirectory(url, grantID: grantID).map {
            NavigationEntry(url: $0.url, identity: $0.identity, kind: $0.isDirectory ? .directory : .document)
        }
    }
}
