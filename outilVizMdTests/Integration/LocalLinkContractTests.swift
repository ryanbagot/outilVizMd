import XCTest
@testable import outilVizMd

final class LocalLinkContractTests: XCTestCase {
    func testAuthorizedLinkAndFragmentResolveWithoutExtendingTheScope() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let target = try corpus.write(Data("# Titre".utf8), to: "inside/target.md")
        let outside = try corpus.write(Data("secret".utf8), to: "outside.md")
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(target.deletingLastPathComponent(), kind: .directory)
        let router = LocalLinkRouter(access: access)
        var components = URLComponents(url: target, resolvingAgainstBaseURL: false)
        components?.fragment = "titre"
        let resolved = try await router.resolve(XCTUnwrap(components?.url))
        XCTAssertEqual(resolved.grantID, grant.id)
        XCTAssertEqual(resolved.url, target)
        XCTAssertEqual(resolved.fragment, "titre")
        do { _ = try await router.resolve(outside); XCTFail("Extension implicite du grant") } catch { }
    }
}
