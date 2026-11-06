import AppKit
import SwiftUI
import XCTest
@testable import outilVizMd

final class NativeInterfacePerformanceTests: XCTestCase {
    @MainActor
    func testTwentyDirectoryPresentationsAndCancellationResponses() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["OUTILVIZMD_PERFORMANCE"] == "20", "Mesures natives explicites")
        let generated = try PerformanceCorpus()
        defer { try? generated.corpus.remove() }
        let directory = try generated.directory()
        let document = try generated.document(mebibytes: 10)
        let model = ReadingCoordinator()
        let window = NSWindow(contentRect: NSRect(x: 90, y: 90, width: 1100, height: 800), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: ReaderWindow(model: model))
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil); window.close() }
        var folders: [Double] = [], cancellations: [Double] = []
        for _ in 0..<20 {
            let start = ProcessInfo.processInfo.systemUptime
            let grant = try await model.files.authorizeSelectedURL(directory, kind: .directory)
            try await model.openFolder(grant)
            XCTAssertEqual(model.navigationRoots.count, 1_000)
            _ = try await paint(window)
            var accessible = false
            for _ in 0..<250 {
                if containsFile(window, depth: 0) { accessible = true; break }
                try await Task.sleep(for: .milliseconds(2))
            }
            guard accessible else {
                var nodes: [String] = []
                describeTree(window, depth: 0, nodes: &nodes)
                let attachment = XCTAttachment(string: nodes.joined(separator: "\n")); attachment.name = "Native AX diagnostic"; attachment.lifetime = .keepAlways; add(attachment)
                throw XCTSkip("Le host unitaire n’expose pas l’arbre AX de NSHostingView. La latence du dossier doit être mesurée dans le host UI ; ce passage ne la certifie pas.")
            }
            folders.append(ProcessInfo.processInfo.systemUptime - start)
            let fileGrant = try await model.files.authorizeSelectedURL(document, kind: .file)
            await model.open(document, grantID: fileGrant.id)
            let id = try XCTUnwrap(model.activeDocumentID)
            try await Task.sleep(for: .milliseconds(1))
            let cancelStart = ProcessInfo.processInfo.systemUptime
            model.close(id)
            _ = try await paint(window)
            XCTAssertNil(model.activeDocumentID)
            XCTAssertNil(model.documents[id])
            cancellations.append(ProcessInfo.processInfo.systemUptime - cancelStart)
        }
        let data = try JSONSerialization.data(withJSONObject: ["method": "command after selection (authorization included), native ReaderWindow layout, bitmap after MainActor turn, first file accessibility element with nonzero frame; no XCTest IPC", "repetitions": 20, "directory_1000_seconds": folders, "cancel_loading_10MiB_seconds": cancellations], options: [.sortedKeys, .prettyPrinted])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "performance-native-interface.json"; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor
    func testTwentyVisibleLoadingCancellations() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["OUTILVIZMD_PERFORMANCE"] == "20", "Mesures natives explicites")
        let generated = try PerformanceCorpus(); defer { try? generated.corpus.remove() }
        let document = try generated.document(mebibytes: 10)
        let original = try Data(contentsOf: document)
        let model = ReadingCoordinator()
        let window = NSWindow(contentRect: NSRect(x: 90, y: 90, width: 1100, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: ReaderWindow(model: model))
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil); window.close() }
        var times: [Double] = []
        for _ in 0..<20 {
            let grant = try await model.files.authorizeSelectedURL(document, kind: .file)
            await model.open(document, grantID: grant.id)
            let id = try XCTUnwrap(model.activeDocumentID)
            let loading = try await paint(window)
            XCTAssertTrue(model.documents[id]?.status == .loading)
            let start = ProcessInfo.processInfo.systemUptime
            model.close(id)
            let closed = try await paint(window)
            times.append(ProcessInfo.processInfo.systemUptime - start)
            XCTAssertNil(model.activeDocumentID)
            XCTAssertNotEqual(try XCTUnwrap(loading.tiffRepresentation), try XCTUnwrap(closed.tiffRepresentation), "Le retour à l’accueil doit être effectivement dessiné")
        }
        XCTAssertEqual(try Data(contentsOf: document), original)
        let data = try JSONSerialization.data(withJSONObject: ["repetitions": 20, "method": "cancel while loading 10 MiB, native frame changed from loading to welcome", "cancel_loading_10MiB_seconds": times], options: [.sortedKeys, .prettyPrinted])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "performance-cancel-visible.json"; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor
    private func containsFile(_ object: Any, depth: Int) -> Bool {
        guard depth < 30, let element = object as? NSAccessibilityProtocol else { return false }
        if element.accessibilityLabel() == "0.md", element.accessibilityFrame().width > 0 { return true }
        let children = element.accessibilityChildren() ?? []
        return children.contains { containsFile($0, depth: depth + 1) }
    }

    @MainActor
    private func describeTree(_ object: Any, depth: Int, nodes: inout [String]) {
        guard depth < 14, nodes.count < 100 else { return }
        guard let element = object as? NSAccessibilityProtocol else { nodes.append("\(depth): \(type(of: object)) (lightweight)"); return }
        nodes.append("\(depth): \(type(of: object)) label=\(element.accessibilityLabel() ?? "") id=\(element.accessibilityIdentifier() ?? "")")
        for child in (element.accessibilityChildren() ?? []).prefix(5) { describeTree(child, depth: depth + 1, nodes: &nodes) }
    }

    @MainActor
    private func paint(_ window: NSWindow) async throws -> NSImage {
        try await Task.sleep(for: .milliseconds(2))
        let view = try XCTUnwrap(window.contentView)
        view.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let image = NSImage(size: view.bounds.size); image.addRepresentation(bitmap)
        return image
    }
}
