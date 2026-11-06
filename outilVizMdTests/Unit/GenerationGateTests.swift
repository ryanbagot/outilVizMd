import XCTest
@testable import outilVizMd

final class GenerationGateTests: XCTestCase {
    func testNewSourceRejectsAnOlderResponseEvenIfItFinishesLater() throws {
        var gate = GenerationGate()
        let document = UUID()
        let old = try gate.beginSource(for: document)
        let latest = try gate.beginSource(for: document)
        XCTAssertFalse(gate.accepts(old))
        XCTAssertTrue(gate.accepts(latest))
        XCTAssertGreaterThan(latest.sourceGeneration, old.sourceGeneration)
    }

    func testThemePresentationRejectsOldThemeWithoutChangingSourceGeneration() throws {
        var gate = GenerationGate()
        let source = try gate.beginSource(for: UUID())
        let theme = try gate.beginPresentation(for: source.documentID)
        XCTAssertEqual(theme.sourceGeneration, source.sourceGeneration)
        XCTAssertGreaterThan(theme.presentationGeneration, source.presentationGeneration)
        XCTAssertFalse(gate.accepts(source))
        XCTAssertTrue(gate.accepts(theme))
    }

    func testBackgroundResponseCannotBeDisplayedAsAnotherActiveDocument() throws {
        var gate = GenerationGate()
        let a = try gate.beginSource(for: UUID())
        let b = try gate.beginSource(for: UUID())
        XCTAssertTrue(gate.accepts(a))
        XCTAssertFalse(gate.canDisplay(a, activeDocumentID: b.documentID))
        XCTAssertTrue(gate.canDisplay(b, activeDocumentID: b.documentID))
        XCTAssertFalse(gate.canDisplay(a, activeDocumentID: nil))
    }

    func testCloseRejectsAllResponsesAndCannotBeUndoneByReusingAnIdentifier() throws {
        var gate = GenerationGate()
        let old = try gate.beginSource(for: UUID())
        gate.close(old.documentID)
        XCTAssertFalse(gate.accepts(old))
        XCTAssertThrowsError(try gate.beginPresentation(for: old.documentID))
        let reopened = try gate.beginSource(for: old.documentID)
        XCTAssertFalse(gate.accepts(old))
        XCTAssertTrue(gate.accepts(reopened))
    }

    func testQueryOrThemeResponseCannotBorrowAnotherDocumentVersion() throws {
        var gate = GenerationGate()
        let a = try gate.beginSource(for: UUID())
        let b = try gate.beginSource(for: UUID())
        let forged = PresentationVersion(documentID: a.documentID,
                                         sourceGeneration: b.sourceGeneration,
                                         presentationGeneration: b.presentationGeneration)
        XCTAssertFalse(gate.accepts(forged))
    }

    @MainActor
    func testCancellationDoesNotAllowALateResponseToReopenClosedDocument() async throws {
        let coordinator = ReadingCoordinator()
        let handle = DocumentHandle(location: URL(fileURLWithPath: "/temporary.md"),
                                    identity: FileIdentity(device: 1, inode: 1), grantID: UUID())
        let work = ControlledAsyncWork<PresentationVersion>()
        let requestID = UUID()
        let ticket = try coordinator.beginLoading(handle)
        let waiting = Task { try await work.run(id: requestID) }
        defer { Task { await work.cancelAll() } }
        for _ in 0..<1_000 {
            if await work.isWaiting(requestID) { break }
            await Task.yield()
        }
        let isWaiting = await work.isWaiting(requestID)
        XCTAssertTrue(isWaiting)
        waiting.cancel()
        coordinator.close(handle.id)
        try await work.resolve(requestID, with: .success(ticket))
        let lateResult = try await waiting.value
        XCTAssertFalse(coordinator.accepts(lateResult))
        XCTAssertNil(coordinator.activeDocumentID)
        XCTAssertFalse(coordinator.openDocumentIDs.contains(handle.id))
    }
}
