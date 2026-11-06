import XCTest

extension ReadingJourneysTests {
    @MainActor
    func testLocalHelpAndNoticesOpenAndCloseWithoutClosingReader() {
        let app = XCUIApplication(); app.launch()
        app.menuBars.menuBarItems["Aide"].click()
        app.menuBars.menuBarItems["Aide"].menus.menuItems["Aide outilVizMd"].click()
        let help = app.windows["Aide outilVizMd"]
        XCTAssertTrue(help.waitForExistence(timeout: 5))
        let helpText = help.descendants(matching: .any).matching(identifier: "local-document-text").firstMatch
        XCTAssertTrue(helpText.waitForExistence(timeout: 5))
        XCTAssertTrue((helpText.label + " " + (helpText.value as? String ?? "")).contains("Lire vos documents Markdown"))
        app.typeKey("w", modifierFlags: .command)
        XCTAssertFalse(help.exists)
        XCTAssertTrue(app.buttons["welcome-open-file"].exists)
        app.menuBars.menuBarItems["Aide"].click()
        app.menuBars.menuBarItems["Aide"].menus.menuItems["Licences des composants"].click()
        let notices = app.windows["Licences des composants"]
        XCTAssertTrue(notices.waitForExistence(timeout: 5))
        let noticesText = notices.descendants(matching: .any).matching(identifier: "local-document-text").firstMatch
        XCTAssertTrue(noticesText.waitForExistence(timeout: 5))
        XCTAssertTrue((noticesText.label + " " + (noticesText.value as? String ?? "")).contains("Apache License"))
        app.typeKey("w", modifierFlags: .command)
        XCTAssertFalse(notices.exists)
    }
}
