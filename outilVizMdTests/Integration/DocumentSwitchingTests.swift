import XCTest
@testable import outilVizMd

final class DocumentSwitchingTests: XCTestCase {
    @MainActor
    func testHomonymsDeduplicationRetainedViewAndRelease() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let a = try corpus.write(Data("# Premier".utf8), to: "a/Guide.md")
        let b = try corpus.write(Data("# Second".utf8), to: "b/Guide.md")
        let model = ReadingCoordinator()
        let grant = try await model.files.authorizeSelectedURL(corpus.root, kind: .directory)
        try await model.files.retain(grant.id)
        await model.open(a, grantID: grant.id)
        let first = try XCTUnwrap(model.activeDocumentID)
        for _ in 0..<200 {
            if model.controller(for: first) != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let view = try XCTUnwrap(model.controller(for: first))
        try await model.files.retain(grant.id)
        await model.open(b, grantID: grant.id)
        let second = try XCTUnwrap(model.activeDocumentID)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(model.documentOrder.count, 2)
        try await model.files.retain(grant.id)
        await model.open(a, grantID: grant.id)
        XCTAssertEqual(model.activeDocumentID, first)
        XCTAssertTrue(model.controller(for: first) === view)
        XCTAssertEqual(model.documentOrder.count, 2)
        model.close(first)
        XCTAssertEqual(model.activeDocumentID, second)
        XCTAssertNil(model.controller(for: first))
        model.close(second)
    }
}
