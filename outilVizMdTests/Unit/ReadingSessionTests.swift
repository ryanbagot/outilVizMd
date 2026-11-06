import XCTest
@testable import outilVizMd

final class ReadingSessionTests: XCTestCase {
    func testUniqueOrderedDocumentsSelectionAndDeterministicClose() {
        var session = ReadingSession()
        let a = UUID(), b = UUID(), c = UUID()
        session.open(a); session.open(b); session.open(c); session.open(a)
        XCTAssertEqual(session.documentIDs, [a, b, c])
        XCTAssertEqual(session.activeDocumentID, a)
        session.select(b); session.close(b)
        XCTAssertEqual(session.activeDocumentID, c)
        session.close(c); session.close(a)
        XCTAssertTrue(session.documentIDs.isEmpty)
        XCTAssertNil(session.activeDocumentID)
        session.select(a)
        XCTAssertNil(session.activeDocumentID)
    }
}
