import XCTest

extension ReadingJourneysTests {
    @MainActor
    func testFolderHomonymsSwitchingAndClosingWithoutSourceChanges() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("navigation-\(UUID().uuidString)", isDirectory: true)
        let a = root.appendingPathComponent("a/Guide.md"), b = root.appendingPathComponent("b/Guide.md")
        try FileManager.default.createDirectory(at: a.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: b.deletingLastPathComponent(), withIntermediateDirectories: true)
        let first = Data("# Premier document\n\nDocument A.\n".utf8)
        let second = Data("# Second document\n\nDocument B.\n".utf8)
        try first.write(to: a); try second.write(to: b)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["welcome-open-folder"].waitForExistence(timeout: 10))
        app.buttons["welcome-open-folder"].click()
        app.typeKey("g", modifierFlags: [.command, .shift])
        let path = app.textFields["PathTextField"]
        XCTAssertTrue(path.waitForExistence(timeout: 5))
        path.click(); app.typeKey("a", modifierFlags: .command)
        app.typeText(root.path + "/"); app.typeKey(.return, modifierFlags: [])
        if path.exists { app.typeKey(.return, modifierFlags: []) }
        let confirm = app.buttons["OKButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.click()
        func item(_ prefix: String, _ suffix: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@", prefix, suffix)).firstMatch
        }
        let folderA = item("directory-folder-", "/a")
        XCTAssertTrue(folderA.waitForExistence(timeout: 10)); folderA.click()
        let documentA = item("directory-document-", "/a/Guide.md")
        XCTAssertTrue(documentA.waitForExistence(timeout: 5)); documentA.click()
        XCTAssertTrue(app.webViews.staticTexts["Premier document"].waitForExistence(timeout: 10))
        let folderB = item("directory-folder-", "/b")
        folderB.click()
        let documentB = item("directory-document-", "/b/Guide.md")
        XCTAssertTrue(documentB.waitForExistence(timeout: 5)); documentB.click()
        XCTAssertTrue(app.webViews.staticTexts["Second document"].waitForExistence(timeout: 10))
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.webViews.staticTexts["Premier document"].waitForExistence(timeout: 5))
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.buttons["welcome-open-file"].waitForExistence(timeout: 5))
        XCTAssertEqual(try Data(contentsOf: a), first)
        XCTAssertEqual(try Data(contentsOf: b), second)
    }

    @MainActor
    func testFolderChoiceCanBeCancelledWithoutChangingTheWelcome() {
        let app = XCUIApplication()
        app.launch()
        let button = app.buttons["welcome-open-folder"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.click()
        let cancel = app.buttons["CancelButton"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.click()
        XCTAssertTrue(app.buttons["welcome-open-file"].exists)
    }
}
