import XCTest
@testable import outilVizMd

final class UntrustedRenderingTests: XCTestCase {
    func testHostileCorpusOnlyProducesInertTextAndOpaqueLinks() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        try corpus.copyFixtures()
        let text = try String(contentsOf: corpus.url("Malicious/active.md"), encoding: .utf8)
        let parsed = await MarkdownParser().parse(text: text, documentID: UUID(), generation: 1)
        let version = PresentationVersion(documentID: parsed.documentID, sourceGeneration: 1, presentationGeneration: 1)
        let preview = try await SafeHTMLRenderer(access: AuthorizedFileAccess()).render(parsed, documentURL: corpus.url("Malicious/active.md"), grantID: UUID(), preferences: .defaults, version: version)
        for active in ["<script", "<iframe", "<svg", "<form", "<input", "<object", "src=\"http", "href=\"http", "href=\"file:", "href=\"javascript:"] {
            XCTAssertFalse(preview.html.contains(active), "Élément actif émis : \(active)")
        }
        XCTAssertTrue(preview.html.contains("Le reste doit rester consultable"))
        XCTAssertTrue(preview.resources.isEmpty)
        for raw in ["javascript:alert(1)", "data:text/html,bonjour", "file:///etc/passwd", "//example.invalid/a.md", "%252e%252e/outside.md", "a%2fb.md", "a\\b.md"] {
            if case .refused = SafeHTMLRenderer.link(raw, relativeTo: corpus.root.appendingPathComponent("a.md")) { }
            else { XCTFail("URL ambiguë ou active acceptée : \(raw)") }
        }
    }

    func testExternalURLsRequireAnExplicitClickAndAnOpaqueKnownLink() throws {
        let token = UUID(), link = UUID()
        let target = try XCTUnwrap(URL(string: "https://example.invalid/page"))
        let preview = PreviewSnapshot(version: PresentationVersion(documentID: UUID(), sourceGeneration: 1, presentationGeneration: 1), html: "", token: token, resources: [], links: [link: .web(target)])
        let internalURL = try XCTUnwrap(URL(string: "outilvizmd://preview/\(token.uuidString)/link/\(link.uuidString)"))
        XCTAssertEqual(NavigationPolicy.decide(internalURL, explicitClick: false, preview: preview), .refuse)
        XCTAssertEqual(NavigationPolicy.decide(internalURL, explicitClick: true, preview: preview), .openExternal(target))
        XCTAssertEqual(NavigationPolicy.decide(target, explicitClick: true, preview: preview), .refuse)
    }
}
