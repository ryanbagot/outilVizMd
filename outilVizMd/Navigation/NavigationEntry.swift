import Foundation

struct NavigationEntry: Identifiable, Sendable {
    enum Kind: Sendable { case directory, document }
    let url: URL
    let identity: FileIdentity
    let kind: Kind
    var children: [NavigationEntry]?
    var failure: ReaderFailure?
    var id: String { url.path }
    var name: String { url.lastPathComponent }
}
