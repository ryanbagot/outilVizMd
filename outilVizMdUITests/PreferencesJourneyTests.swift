import XCTest

extension ReadingJourneysTests {
    @MainActor
    func testPreferencesSurviveThreeRealRelaunchesAndReset() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment["OUTILVIZMD_TEST_PREFERENCES_ID"] = UUID().uuidString
        app.launch()
        app.typeKey(",", modifierFlags: .command)
        let theme = app.popUpButtons["preference-theme"]
        XCTAssertTrue(theme.waitForExistence(timeout: 10))
        theme.click(); app.menuItems["Sombre"].click()
        let style = app.popUpButtons["preference-style"]
        style.click(); app.menuItems["Aéré"].click()
        XCTAssertTrue(app.buttons["preferences-reset"].exists)
        for _ in 0..<3 {
            app.terminate(); app.launch()
            XCTAssertTrue(app.buttons["welcome-open-file"].waitForExistence(timeout: 10))
            app.typeKey(",", modifierFlags: .command)
            XCTAssertTrue(theme.waitForExistence(timeout: 10))
            XCTAssertEqual(theme.value as? String, "Sombre")
            XCTAssertEqual(style.value as? String, "Aéré")
        }
        app.buttons["preferences-reset"].click()
        app.terminate(); app.launch()
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(theme.waitForExistence(timeout: 10))
        XCTAssertEqual(theme.value as? String, "Système")
        XCTAssertEqual(style.value as? String, "Standard")
    }
}
