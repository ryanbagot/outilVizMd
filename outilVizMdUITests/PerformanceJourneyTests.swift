import XCTest
import AppKit

extension ReadingJourneysTests {
    @MainActor
    func testTwentyCancellationAndDirectoryPresentations() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["OUTILVIZMD_PERFORMANCE"] == "20", "Benchmark UI explicite")
        let repetitions = min(20, max(1, Int(ProcessInfo.processInfo.environment["OUTILVIZMD_UI_REPETITIONS"] ?? "20") ?? 20))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dossier-perf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for folder in 0..<repetitions {
            let directory = root.appendingPathComponent(String(folder))
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for index in 0..<1_000 { try Data("# Document \(index)".utf8).write(to: directory.appendingPathComponent("\(index).md")) }
        }
        let app = XCUIApplication(); app.launch()
        var cancellations: [Double] = [], directories: [Double] = []
        for iteration in 0..<repetitions {
            app.typeKey("o", modifierFlags: .command)
            let cancel = app.buttons.matching(identifier: "CancelButton").firstMatch
            XCTAssertTrue(cancel.waitForExistence(timeout: 5))
            let start = ProcessInfo.processInfo.systemUptime
            cancel.click()
            XCTAssertTrue(app.buttons.matching(identifier: "welcome-open-file").firstMatch.waitForExistence(timeout: 5))
            cancellations.append(ProcessInfo.processInfo.systemUptime - start)
            app.typeKey("o", modifierFlags: [.command, .shift])
            XCTAssertTrue(cancel.waitForExistence(timeout: 5))
            app.typeKey("g", modifierFlags: [.command, .shift])
            let field = app.textFields.matching(identifier: "PathTextField").firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.click(); app.typeKey("a", modifierFlags: .command); pasteBenchmarkPath(root.appendingPathComponent(String(iteration)).path, in: app)
            app.typeKey(.return, modifierFlags: [])
            if field.exists { app.typeKey(.return, modifierFlags: []) }
            let directoryStart = ProcessInfo.processInfo.systemUptime
            app.buttons.matching(identifier: "OKButton").firstMatch.click()
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@", "directory-document-", "/\(iteration)/0.md")).firstMatch.waitForExistence(timeout: 5))
            directories.append(ProcessInfo.processInfo.systemUptime - directoryStart)
        }
        let data = try JSONSerialization.data(withJSONObject: ["repetitions": repetitions, "method": "XCUITest click-to-visible (includes automation IPC overhead)", "cancel_seconds": cancellations, "directory_1000_seconds": directories], options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "performance-ui.json"; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor
    private func pasteBenchmarkPath(_ path: String, in app: XCUIApplication) {
        let pasteboard = NSPasteboard.general
        let original = (pasteboard.pasteboardItems ?? []).map { source in
            let item = NSPasteboardItem()
            for type in source.types { if let data = source.data(forType: type) { item.setData(data, forType: type) } }
            return item
        }
        defer { pasteboard.clearContents(); pasteboard.writeObjects(original) }
        pasteboard.clearContents(); pasteboard.setString(path, forType: .string)
        app.typeKey("v", modifierFlags: .command)
    }

}
