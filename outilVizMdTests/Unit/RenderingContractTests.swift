import XCTest
@testable import outilVizMd

final class RenderingContractTests: XCTestCase {
    func testHTMLIsEscapedAndRemoteURLsNeverBecomeSubresources() async throws {
        let parsed = await MarkdownParser().parse(text: "# Titre\n\n<script>alert(1)</script>\n\n![non](https://example.invalid/a.png)\n\n[non](javascript:alert%281%29)", documentID: UUID(), generation: 1)
        let version = PresentationVersion(documentID: parsed.documentID, sourceGeneration: 1, presentationGeneration: 1)
        let preview = try await SafeHTMLRenderer(access: AuthorizedFileAccess()).render(parsed, documentURL: URL(fileURLWithPath: "/a.md"), grantID: UUID(), preferences: .defaults, version: version)
        XCTAssertFalse(preview.html.contains("<script>"))
        XCTAssertTrue(preview.html.contains("&lt;script&gt;"))
        XCTAssertFalse(preview.html.contains("src=\"https:"))
        XCTAssertFalse(preview.html.contains("href=\"javascript:"))
        XCTAssertTrue(preview.html.contains("non"))
    }

    @MainActor
    func testResourceTokensAreIsolatedRevokedAndNeverFilePaths() throws {
        let store = PreviewResourceStore()
        let version = PresentationVersion(documentID: UUID(), sourceGeneration: 1, presentationGeneration: 1)
        let preview = PreviewSnapshot(version: version, html: "<p>ok</p>", token: UUID(), resources: [])
        store.install(preview)
        let url = try XCTUnwrap(URL(string: "outilvizmd://preview/\(preview.token.uuidString)/document"))
        XCTAssertEqual(try store.resource(for: url).mime, .html)
        for raw in ["outilvizmd://preview/\(UUID().uuidString)/document", url.absoluteString + "?x=1", "file:///etc/passwd", "outilvizmd://preview/\(preview.token.uuidString)/%64ocument"] {
            XCTAssertThrowsError(try store.resource(for: XCTUnwrap(URL(string: raw))))
        }
        store.revoke(preview.token)
        XCTAssertThrowsError(try store.resource(for: url))
    }

    func testRasterResourcesAreValidatedAndGIFBecomesPNG() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        try corpus.copyFixtures()
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(corpus.root, kind: .directory)
        let loader = LocalImageLoader(access: access)
        for name in ["sample.png", "sample.jpg", "sample.gif"] {
            let image = try await loader.load(corpus.url("Images/" + name), grantID: grant.id, token: UUID(), alternativeText: "exemple")
            XCTAssertTrue(image.mime == .png || image.mime == .jpeg)
            XCTAssertNotNil(image.pixelWidth)
        }
    }
}
