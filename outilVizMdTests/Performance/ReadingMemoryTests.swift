import AppKit
import SwiftUI
import XCTest
@testable import outilVizMd

final class ReadingMemoryTests: XCTestCase {
    @MainActor
    func testTenDocumentsAndCloseReleaseTheSession() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["OUTILVIZMD_PERFORMANCE"] == "20", "Mesure mémoire explicite")
        let generated = try PerformanceCorpus()
        defer { try? generated.corpus.remove() }
        let original = try generated.document(mebibytes: 1)
        let bytes = try Data(contentsOf: original)
        let model = ReadingCoordinator()
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 1000, height: 750), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: ReaderWindow(model: model))
        window.orderFront(nil)
        defer { window.orderOut(nil); window.close() }
        var record = ["before": PerformanceMemory.sample()]
        for index in 0..<10 {
            let url = try generated.corpus.write(bytes, to: "memory-\(index).md")
            let grant = try await model.files.authorizeSelectedURL(generated.corpus.root, kind: .directory)
            await model.open(url, grantID: grant.id)
            let id = try XCTUnwrap(model.activeDocumentID)
            for _ in 0..<2_000 {
                if let preview = model.documents[id]?.preview, model.renderedVersions[id] == preview.version { break }
                try await Task.sleep(for: .milliseconds(5))
            }
            XCTAssertTrue(model.documents[id]?.status == .ready)
        }
        record["ten_documents"] = PerformanceMemory.sample()
        for id in model.documentOrder { model.close(id) }
        try await Task.sleep(for: .milliseconds(500))
        record["closed"] = PerformanceMemory.sample()
        XCTAssertTrue(model.documents.isEmpty)
        XCTAssertTrue(model.documentOrder.isEmpty)
        XCTAssertTrue(model.renderedVersions.isEmpty)
        let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys, .prettyPrinted])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "performance-memory-app-only.json"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
