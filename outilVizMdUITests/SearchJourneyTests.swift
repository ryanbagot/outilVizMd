import XCTest

extension ReadingJourneysTests {
    @MainActor
    func testSearchCounterLoopAndEscapeOnRealWebKitPage() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("recherche-\(UUID().uuidString).md")
        let bytes = Data("# Café au lait\n\nCafé **au** lait\n".utf8)
        try bytes.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let app = XCUIApplication()
        app.launch()
        try openDocument(url, in: app)
        XCTAssertTrue(app.webViews.staticTexts["Café au lait"].firstMatch.waitForExistence(timeout: 10))
        app.typeKey("f", modifierFlags: .command)
        let query = app.textFields["search-query"]
        XCTAssertTrue(query.waitForExistence(timeout: 5))
        query.typeText("café au lait")
        let first = app.staticTexts["1 sur 2"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        app.buttons["Résultat précédent"].click()
        XCTAssertTrue(app.staticTexts["2 sur 2"].waitForExistence(timeout: 10))
        app.buttons["Résultat suivant"].click()
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        query.click()
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(query.exists)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    @MainActor
    func openDocument(_ url: URL, in app: XCUIApplication) throws {
        app.typeKey("o", modifierFlags: .command)
        XCTAssertTrue(app.buttons["CancelButton"].waitForExistence(timeout: 5))
        app.typeKey("g", modifierFlags: [.command, .shift])
        let field = app.textFields["PathTextField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText(url.path)
        app.typeKey(.return, modifierFlags: [])
        if field.exists { app.typeKey(.return, modifierFlags: []) }
        app.buttons["OKButton"].click()
        XCTAssertTrue(app.windows[url.lastPathComponent].waitForExistence(timeout: 10))
    }
}
