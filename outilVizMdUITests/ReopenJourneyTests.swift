import XCTest
import AppKit

final class ReopenJourneyTests: XCTestCase {
    @MainActor func testReopenRestoresReaderWithOtherWindowsPresent() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["welcome-open-file"].waitForExistence(timeout: 10))
        let document = FileManager.default.temporaryDirectory.appendingPathComponent("session-reopen-\(UUID().uuidString).md")
        let bytes = Data("# Session conservée\n\nLecture locale.\n".utf8)
        try bytes.write(to: document)
        addTeardownBlock { try? FileManager.default.removeItem(at: document) }
        app.typeKey("o", modifierFlags: .command)
        app.typeKey("g", modifierFlags: [.command, .shift])
        let path = app.textFields["PathTextField"]
        XCTAssertTrue(path.waitForExistence(timeout: 5))
        path.click(); app.typeKey("a", modifierFlags: .command); app.typeText(document.path)
        app.typeKey(.return, modifierFlags: [])
        if path.exists { app.typeKey(.return, modifierFlags: []) }
        let open = app.buttons["OKButton"]
        XCTAssertTrue(open.waitForExistence(timeout: 5)); open.click()
        let content = app.webViews.staticTexts["Session conservée"].firstMatch
        XCTAssertTrue(content.waitForExistence(timeout: 10))
        let product = Bundle(for: Self.self).bundleURL
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("outilVizMd.app").resolvingSymlinksInPath()
        let running = try XCTUnwrap(NSRunningApplication.runningApplications(withBundleIdentifier: "com.outilvizmd.outilVizMd").first { $0.bundleURL?.resolvingSymlinksInPath() == product })
        let bundle = try XCTUnwrap(running.bundleURL)
        let pid = running.processIdentifier
        func reopen() async throws {
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = false
            config.allowsRunningApplicationSubstitution = false
            let reopened = try await NSWorkspace.shared.openApplication(at: bundle, configuration: config)
            XCTAssertEqual(reopened.processIdentifier, pid)
        }
        try await reopen()
        XCTAssertTrue(content.waitForExistence(timeout: 5))
        let reader = app.windows[document.lastPathComponent]
        reader.buttons[XCUIIdentifierMinimizeWindow].click()
        try await reopen()
        XCTAssertTrue(content.waitForExistence(timeout: 5))
        XCTAssertTrue(app.webViews.firstMatch.isHittable)
        app.typeKey(",", modifierFlags: .command)
        reader.buttons[XCUIIdentifierCloseWindow].click()
        try await reopen()
        XCTAssertTrue(content.waitForExistence(timeout: 5))
        XCTAssertTrue(app.webViews.firstMatch.isHittable)
        app.menuBars.menuBarItems["Aide"].click()
        app.menuBars.menuBarItems["Aide"].menus.menuItems["Aide outilVizMd"].click()
        reader.buttons[XCUIIdentifierCloseWindow].click()
        try await reopen()
        XCTAssertTrue(content.waitForExistence(timeout: 5))
        XCTAssertEqual(try Data(contentsOf: document), bytes)
        XCTAssertEqual(NSRunningApplication.runningApplications(withBundleIdentifier: "com.outilvizmd.outilVizMd").filter { $0.bundleURL == bundle }.count, 1)
    }
}
