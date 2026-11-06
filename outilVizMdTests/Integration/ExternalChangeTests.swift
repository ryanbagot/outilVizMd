import XCTest
@testable import outilVizMd

final class ExternalChangeTests: XCTestCase {
    @MainActor
    func testDirectAtomicBurstDeletionRecreationAndInactiveDocument() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let url = try corpus.write(Data("# Version initiale".utf8), to: "doc.md")
        let model = ReadingCoordinator()
        let grant = try await model.files.authorizeSelectedURL(url, kind: .file)
        await model.open(url, grantID: grant.id)
        let id = try XCTUnwrap(model.activeDocumentID)
        try await wait { model.documents[id]?.snapshot?.text == "# Version initiale" }
        try Data("# Écriture directe".utf8).write(to: url)
        try await wait { model.documents[id]?.snapshot?.text == "# Écriture directe" }
        model.presentSearch(); model.updateSearch("Version")
        for index in 0..<10 { try Data("# Version \(index)".utf8).write(to: url, options: .atomic) }
        try await wait { model.documents[id]?.snapshot?.text == "# Version 9" && model.searchState?.total == 1 }
        try FileManager.default.removeItem(at: url)
        try await wait { model.documents[id]?.status == .stale }
        XCTAssertNotNil(model.documents[id]?.preview)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        try Data("# Recréé".utf8).write(to: url)
        try await wait { model.documents[id]?.snapshot?.text == "# Recréé" && model.documents[id]?.status == .ready }
        let second = try corpus.write(Data("# Deuxième".utf8), to: "second.md")
        let nextGrant = try await model.files.authorizeSelectedURL(second, kind: .file)
        await model.open(second, grantID: nextGrant.id)
        try await wait { model.documents.count == 2 }
        try Data("# Inactif modifié".utf8).write(to: url, options: .atomic)
        try await wait { model.documents[id]?.status == .stale }
        model.select(id)
        try await wait { model.documents[id]?.snapshot?.text == "# Inactif modifié" }
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "# Inactif modifié")
        model.close(id)
        if let active = model.activeDocumentID { model.close(active) }
    }
    @MainActor
    func testLateBurstNotificationsDoNotMarkCurrentInactivePreviewStale() async throws {
        let corpus = try TemporaryCorpus(); defer { try? corpus.remove() }
        let first = try corpus.write(Data("# Initial".utf8), to: "first.md")
        let second = try corpus.write(Data("# Second".utf8), to: "second.md")
        let model = ReadingCoordinator()
        let grant = try await model.files.authorizeSelectedURL(corpus.root, kind: .directory)
        await model.open(first, grantID: grant.id)
        let id = try XCTUnwrap(model.activeDocumentID)
        try await wait { model.documents[id]?.status == .ready }
        for cycle in 0..<10 {
            for index in 0..<10 { try Data("# Version \(cycle)-\(index)".utf8).write(to: first, options: .atomic) }
            try await wait { model.documents[id]?.snapshot?.text == "# Version \(cycle)-9" && model.documents[id]?.status == .ready }
            try await model.files.retain(grant.id)
            await model.open(second, grantID: grant.id)
            let other = try XCTUnwrap(model.activeDocumentID)
            try await wait { model.documents[other]?.status == .ready }
            try await Task.sleep(for: .milliseconds(200))
            XCTAssertTrue(model.documents[id]?.status == .ready)
            model.select(id)
            try await wait { model.documents[id]?.status == .ready }
            model.close(other)
        }
        model.close(id)
    }

    @MainActor
    private func wait(_ predicate: () -> Bool) async throws {
        for _ in 0..<200 { if predicate() { return }; try await Task.sleep(for: .milliseconds(25)) }
        XCTFail("Changement externe non reflété")
    }
}
