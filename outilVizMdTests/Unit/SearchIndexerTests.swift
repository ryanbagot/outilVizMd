import XCTest
@testable import outilVizMd

final class SearchIndexerTests: XCTestCase {
    func testLiteralUnicodeMatchesSpanInlineNodesAndRespectAccents() async throws {
        let parsed = await MarkdownParser().parse(text: "# Café **au** lait\n\nCAFÉ au lait et cafe\n\n`[a].*`\n\n![Absent](remote.png)", documentID: UUID(), generation: 1)
        let index = VisibleTextIndex(parsed.visibleText)
        let matches = await SearchIndexer().find("café au lait", in: index)
        XCTAssertEqual(matches.count, 2)
        XCTAssertGreaterThan(matches[0].segments.count, 1)
        XCTAssertEqual(awaitCount("cafe", index), 1)
        let literal = await SearchIndexer().find("[a].*", in: index)
        XCTAssertEqual(literal.count, 1)
        let missing = await SearchIndexer().find("https://invisible", in: index)
        XCTAssertTrue(missing.isEmpty)
        let alt = await SearchIndexer().find("Image indisponible : Absent", in: index)
        XCTAssertEqual(alt.count, 1)
    }

    private func awaitCount(_ query: String, _ index: VisibleTextIndex) -> Int {
        // Variante synchrone réservée au contrat pur.
        SearchIndexer.matches(query, in: index).count
    }

    func testNonOverlappingEmptyAndUnicodeBoundaries() {
        let projection = VisibleTextProjection(text: "aaaa 👩🏽‍💻 é é", runs: [VisibleTextRun(nodeID: 1, visibleUTF16Range: 0..<20, nodeUTF16Range: 0..<20)], blockBoundaries: [])
        let index = VisibleTextIndex(projection)
        XCTAssertEqual(SearchIndexer.matches("aa", in: index).count, 2)
        XCTAssertTrue(SearchIndexer.matches("", in: index).isEmpty)
        XCTAssertTrue(SearchIndexer.matches("🏽", in: index).isEmpty)
        XCTAssertEqual(SearchIndexer.matches("é", in: index).count, 2)
    }
}
