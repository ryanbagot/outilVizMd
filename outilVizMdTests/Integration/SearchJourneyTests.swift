import XCTest
@testable import outilVizMd

final class SearchJourneyTests: XCTestCase {
    @MainActor
    func testRapidQueriesLoopResetAndClosingRejectStalePresentation() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let url = try corpus.write(Data("# Café **au** lait\n\nCafé au lait.\n".utf8), to: "document.md")
        let source = try Data(contentsOf: url)
        let model = ReadingCoordinator()
        let grant = try await model.files.authorizeSelectedURL(url, kind: .file)
        await model.open(url, grantID: grant.id)
        let id = try XCTUnwrap(model.activeDocumentID)
        try await wait { model.documents[id]?.status == .ready }
        model.presentSearch()
        model.updateSearch("absent")
        model.updateSearch("café au lait")
        try await wait { model.searchState?.total == 2 }
        XCTAssertEqual(model.searchState?.currentIndex, 0)
        model.moveSearch(-1)
        try await wait { model.searchState?.currentIndex == 1 && model.documents[id]?.preview?.html.contains("id=\"search-1\" class=\"current-result\"") == true }
        model.moveSearch(1)
        XCTAssertEqual(model.searchState?.currentIndex, 0)
        model.closeSearch()
        try await wait { model.documents[id]?.preview?.html.contains("<mark") == false }
        XCTAssertNil(model.searchState)
        model.presentSearch()
        model.updateSearch("Café")
        model.close(id)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(model.documents.isEmpty)
        XCTAssertNil(model.searchState)
        XCTAssertEqual(try Data(contentsOf: url), source)
    }

    @MainActor
    private func wait(_ predicate: () -> Bool) async throws {
        for _ in 0..<200 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTFail("Résultat attendu non publié dans le délai")
    }
}
