import XCTest

extension ReadingJourneysTests {
    @MainActor
    func testWelcomeAndCancelledOpeningPreserveTheEmptySession() {
        let app = XCUIApplication()
        app.launch()
        let open = app.buttons["welcome-open-file"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["welcome-open-folder"].exists)
        open.click()
        let cancel = app.buttons["CancelButton"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.click()
        XCTAssertTrue(open.exists)
    }

    @MainActor
    func testOpenReadAndCloseARealDocumentWithoutChangingItsBytes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lecture-\(UUID().uuidString).md")
        let bytes = Data("# Bonjour lecteur\n\nUn document **lisible**.\n".utf8)
        try bytes.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["welcome-open-file"].waitForExistence(timeout: 10))
        app.buttons["welcome-open-file"].click()
        app.typeKey("g", modifierFlags: [.command, .shift])
        let path = app.textFields["PathTextField"]
        XCTAssertTrue(path.waitForExistence(timeout: 5))
        path.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText(url.path)
        app.typeKey(.return, modifierFlags: [])
        if path.exists { app.typeKey(.return, modifierFlags: []) }
        let open = app.buttons["OKButton"]
        let diagnostic = XCTAttachment(string: app.debugDescription)
        diagnostic.name = "Panneau d’ouverture"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.click()
        XCTAssertTrue(app.windows[url.lastPathComponent].waitForExistence(timeout: 10))
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.webViews.staticTexts["Bonjour lecteur"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.buttons["welcome-open-file"].waitForExistence(timeout: 5))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
}
