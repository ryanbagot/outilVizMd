import XCTest
@testable import outilVizMd

final class DirectoryNavigatorTests: XCTestCase {
    func testOneLevelFilteringLazyChildrenAndExplicitRefresh() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        _ = try corpus.write(Data("# A".utf8), to: "a.MD")
        _ = try corpus.write(Data("# B".utf8), to: "b.MARKDOWN")
        _ = try corpus.write(Data("secret".utf8), to: "ignored.txt")
        _ = try corpus.write(Data("# C".utf8), to: "sub/c.md")
        try FileManager.default.createSymbolicLink(at: corpus.root.appendingPathComponent("cycle"), withDestinationURL: corpus.root)
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(corpus.root, kind: .directory)
        let navigator = DirectoryNavigator(access: access)
        let entries = try await navigator.entries(at: corpus.root, grantID: grant.id)
        XCTAssertEqual(entries.map(\.name), ["a.MD", "b.MARKDOWN", "sub"])
        XCTAssertNil(entries.last?.children)
        _ = try corpus.write(Data("# D".utf8), to: "d.md")
        let refreshed = try await navigator.entries(at: corpus.root, grantID: grant.id)
        XCTAssertEqual(refreshed.count, 4)
        let child = try await navigator.entries(at: corpus.root.appendingPathComponent("sub"), grantID: grant.id)
        XCTAssertEqual(child.map(\.name), ["c.md"])
    }
}
