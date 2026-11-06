import XCTest
@testable import outilVizMd

final class OpeningPreviewTests: XCTestCase {
    func testAuthorizedDocumentPipelinePreservesTheOriginal() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        try corpus.copyFixtures()
        let url = try corpus.url("CommonMark.md")
        let reference = try ReferenceSource(url)
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(corpus.root, kind: .directory)
        let handle = try await access.handle(for: url, grantID: grant.id)
        let snapshot = try await LocalDocumentReader(access: access).read(handle: handle, generation: 1)
        let parsed = await MarkdownParser().parse(snapshot)
        let version = PresentationVersion(documentID: handle.id, sourceGeneration: 1, presentationGeneration: 1)
        let preview = try await SafeHTMLRenderer(access: access).render(parsed, documentURL: url, grantID: grant.id, preferences: .defaults, version: version)
        XCTAssertTrue(preview.html.contains("<table>"))
        XCTAssertTrue(preview.html.contains("<pre>"))
        XCTAssertGreaterThanOrEqual(preview.resources.count, 3)
        try assertSourcePreserved(reference, at: url)
    }
}
