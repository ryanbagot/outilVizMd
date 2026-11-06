import XCTest

extension ReadingJourneysTests {
    @MainActor
    func testExternalReplacementDeletionAndRecreationReachTheVisiblePage() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("suivi-\(UUID().uuidString).md")
        try Data("# Première version".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let app = XCUIApplication(); app.launch()
        try openDocument(url, in: app)
        XCTAssertTrue(app.webViews.staticTexts["Première version"].firstMatch.waitForExistence(timeout: 10))
        try Data("# Nouvelle version".utf8).write(to: url, options: .atomic)
        XCTAssertTrue(app.webViews.staticTexts["Nouvelle version"].firstMatch.waitForExistence(timeout: 10))
        try FileManager.default.removeItem(at: url)
        XCTAssertTrue(app.staticTexts["Aperçu non à jour"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.webViews.staticTexts["Nouvelle version"].firstMatch.exists)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        try Data("# Document recréé".utf8).write(to: url)
        XCTAssertTrue(app.webViews.staticTexts["Document recréé"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "# Document recréé")
    }
}
