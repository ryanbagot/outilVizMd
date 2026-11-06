import XCTest
@testable import outilVizMd

final class SearchRenderingContractTests: XCTestCase {
    func testLogicalOccurrenceIsSplitIntoEscapedNodeSegments() async throws {
        let text = "Un **café** au lait et <script>"
        let parsed = await MarkdownParser().parse(text: text, documentID: UUID(), generation: 1)
        let matches = SearchIndexer.matches("café au lait", in: VisibleTextIndex(parsed.visibleText))
        let state = SearchState(documentID: parsed.documentID, sourceGeneration: 1, queryGeneration: 1, query: "café au lait", matches: matches, currentIndex: 0)
        let version = PresentationVersion(documentID: parsed.documentID, sourceGeneration: 1, presentationGeneration: 1)
        let renderer = SafeHTMLRenderer(access: AuthorizedFileAccess())
        let preview = try await renderer.render(parsed, documentURL: URL(fileURLWithPath: "/document.md"), grantID: UUID(), preferences: .defaults, version: version, search: state)
        XCTAssertEqual(preview.html.components(separatedBy: "id=\"search-0\"").count - 1, 1)
        XCTAssertGreaterThan(preview.html.components(separatedBy: "<mark").count - 1, 1)
        XCTAssertTrue(preview.html.contains("&lt;script&gt;"))
        let empty = try await renderer.render(parsed, documentURL: URL(fileURLWithPath: "/document.md"), grantID: UUID(), preferences: .defaults, version: version)
        XCTAssertFalse(empty.html.contains("<mark"))
    }
    func testCollapsedSpacesAcrossLinksUseTheExactSameProjectionAndMarkup() async throws {
        let parsed = await MarkdownParser().parse(text: "a [ b ](https://example.invalid) c", documentID: UUID(), generation: 1)
        let projection = VisibleTextProjector.project(parsed.root)
        XCTAssertTrue(projection.text.hasPrefix("a b c"))
        let matches = SearchIndexer.matches("a b c", in: VisibleTextIndex(projection))
        XCTAssertEqual(matches.count, 1)
        let search = SearchState(documentID: parsed.documentID, sourceGeneration: 1, queryGeneration: 1, query: "a b c", matches: matches, currentIndex: 0)
        let preview = try await SafeHTMLRenderer(access: AuthorizedFileAccess()).render(parsed, documentURL: URL(fileURLWithPath: "/doc.md"), grantID: UUID(), preferences: .defaults, version: PresentationVersion(documentID: parsed.documentID, sourceGeneration: 1, presentationGeneration: 1), search: search)
        XCTAssertEqual(preview.html.components(separatedBy: "id=\"search-0\"").count - 1, 1)
        XCTAssertEqual(preview.visibleText?.text, projection.text)
    }

}
