import AppKit
import SwiftUI
import WebKit
import XCTest
@testable import outilVizMd

final class ReadingPerformanceTests: XCTestCase {
    @MainActor
    func testVisibleReadingBaseline() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["OUTILVIZMD_PERFORMANCE"] == "1", "Mesures explicites : OUTILVIZMD_PERFORMANCE=1 dans le scheme de test")
        try await run(repetitions: 1)
    }
    @MainActor
    func testTwentyVisibleReadingMeasurements() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["OUTILVIZMD_PERFORMANCE"] == "20", "Mesures explicites : OUTILVIZMD_PERFORMANCE=20 dans le scheme de test")
        try await run(repetitions: 20)
    }

    @MainActor
    private func run(repetitions: Int) async throws {
        let generated = try PerformanceCorpus()
        defer { try? generated.corpus.remove() }
        var samples: [String: [Double]] = [:]
        var fingerprints: [[String: String]] = []
        var stage = "start"
        defer {
            let partial: [String: Any] = ["stage": stage, "repetitions": repetitions, "seconds": samples]
            if let data = try? JSONSerialization.data(withJSONObject: partial, options: [.prettyPrinted, .sortedKeys]) {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "performance-progress.json"; attachment.lifetime = .keepAlways; add(attachment)
            }
        }
        for size in [1, 10] {
            let url = try generated.document(mebibytes: size)
            fingerprints.append(try generated.fingerprint(url))
            for iteration in 0..<repetitions {
                let model = ReadingCoordinator()
                let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 1100, height: 800), styleMask: [.titled, .closable], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.contentViewController = NSHostingController(rootView: ReaderWindow(model: model))
                window.orderFront(nil)
                defer { window.orderOut(nil); window.close() }
                stage = "open \(size) MiB iteration \(iteration)"
                let start = ProcessInfo.processInfo.systemUptime
                let grant = try await model.files.authorizeSelectedURL(generated.corpus.root, kind: .directory)
                await model.open(url, grantID: grant.id)
                let id = try XCTUnwrap(model.activeDocumentID)
                try await ready(model, id: id)
                try await paint(model, id: id)
                samples["open_\(size)MiB", default: []].append(ProcessInfo.processInfo.systemUptime - start)
                model.presentSearch()
                stage = "search \(size) MiB iteration \(iteration)"
                let searchStart = ProcessInfo.processInfo.systemUptime
                let searchPrior = model.documents[id]?.preview?.version
                model.updateSearch("occurrence rare")
                try await countReady(model, query: "occurrence rare")
                samples["search_count_\(size)MiB", default: []].append(ProcessInfo.processInfo.systemUptime - searchStart)
                try await ready(model, id: id, query: "occurrence rare", differentFrom: searchPrior)
                try await paint(model, id: id)
                samples["search_\(size)MiB", default: []].append(ProcessInfo.processInfo.systemUptime - searchStart)
                stage = "dense \(size) MiB iteration \(iteration)"
                let denseStart = ProcessInfo.processInfo.systemUptime
                let densePrior = model.documents[id]?.preview?.version
                model.updateSearch("lecture")
                try await countReady(model, query: "lecture")
                samples["dense_count_\(size)MiB", default: []].append(ProcessInfo.processInfo.systemUptime - denseStart)
                try await ready(model, id: id, query: "lecture", differentFrom: densePrior)
                try await paint(model, id: id)
                samples["dense_render_\(size)MiB", default: []].append(ProcessInfo.processInfo.systemUptime - denseStart)
                stage = "restore search \(size) MiB iteration \(iteration)"
                let restorePrior = model.documents[id]?.preview?.version
                model.updateSearch("occurrence rare")
                try await ready(model, id: id, query: "occurrence rare", differentFrom: restorePrior)
                stage = "theme \(size) MiB iteration \(iteration)"
                let themeStart = ProcessInfo.processInfo.systemUptime
                var prefs = RenderPreferences.defaults; prefs.theme = .dark
                let oldVersion = model.documents[id]?.preview?.version
                model.updatePreferences(prefs)
                try await ready(model, id: id, differentFrom: oldVersion)
                try await paint(model, id: id)
                samples["theme_\(size)MiB", default: []].append(ProcessInfo.processInfo.systemUptime - themeStart)
                stage = "external \(size) MiB iteration \(iteration)"
                let changeStart = ProcessInfo.processInfo.systemUptime
                var changed = try Data(contentsOf: url); changed[0] = iteration.isMultiple(of: 2) ? 32 : 35
                try changed.write(to: url, options: .atomic)
                let prior = model.documents[id]?.preview?.version
                try await ready(model, id: id, differentFrom: prior)
                try await paint(model, id: id)
                samples["external_\(size)MiB", default: []].append(ProcessInfo.processInfo.systemUptime - changeStart)
                stage = "burst \(size) MiB iteration \(iteration)"
                let burstPrior = model.documents[id]?.preview?.version
                for value in 0..<10 {
                    changed[0] = value.isMultiple(of: 2) ? 32 : 35
                    try changed.write(to: url, options: .atomic)
                }
                let burstStart = ProcessInfo.processInfo.systemUptime
                try await ready(model, id: id, differentFrom: burstPrior)
                try await paint(model, id: id)
                samples["burst_\(size)MiB", default: []].append(ProcessInfo.processInfo.systemUptime - burstStart)
                stage = "switch setup \(size) MiB iteration \(iteration)"
                let secondURL = try generated.corpus.write(Data("# Autre document".utf8), to: "second.md")
                let secondGrant = try await model.files.authorizeSelectedURL(secondURL, kind: .file)
                let switchPrior = model.documents[id]?.preview?.version
                await model.open(secondURL, grantID: secondGrant.id)
                let secondID = try XCTUnwrap(model.activeDocumentID)
                try await ready(model, id: secondID)
                try await ready(model, id: id, differentFrom: switchPrior)
                stage = "switch \(size) MiB iteration \(iteration)"
                let switchStart = ProcessInfo.processInfo.systemUptime
                model.select(id)
                try await ready(model, id: id)
                try await paint(model, id: id)
                samples["switch_\(size)MiB", default: []].append(ProcessInfo.processInfo.systemUptime - switchStart)
                model.close(secondID)
                model.close(id)
            }
        }
        let directory = try generated.directory()
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(directory, kind: .directory)
        let navigator = DirectoryNavigator(access: access)
        for _ in 0..<repetitions {
            let start = ProcessInfo.processInfo.systemUptime
            let entries = try await navigator.entries(at: directory, grantID: grant.id)
            XCTAssertEqual(entries.count, 1_000)
            samples["directory_1000_service", default: []].append(ProcessInfo.processInfo.systemUptime - start)
        }
        _ = await access.release(grant.id)
        let record: [String: Any] = ["repetitions": repetitions, "configuration": "native ReaderWindow, command to didFinish then visible WebKit snapshot", "os": ProcessInfo.processInfo.operatingSystemVersionString, "physicalMemory": ProcessInfo.processInfo.physicalMemory, "corpus": fingerprints, "seconds": samples]
        let data = try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "performance-reading.json"; attachment.lifetime = .keepAlways; add(attachment)
        print("PERFORMANCE " + String(decoding: data, as: UTF8.self))
    }

    @MainActor
    private func countReady(_ model: ReadingCoordinator, query: String) async throws {
        for _ in 0..<12_000 {
            if model.searchState?.query == query { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw ReaderFailure.previewProtectionUnavailable
    }

    @MainActor
    private func ready(_ model: ReadingCoordinator, id: UUID, query: String? = nil, differentFrom old: PresentationVersion? = nil) async throws {
        for _ in 0..<12_000 {
            if let preview = model.documents[id]?.preview, model.renderedVersions[id] == preview.version,
               model.documents[id]?.status == .ready, old == nil || old != preview.version,
               query == nil || model.searchState?.query == query { return }
            if model.documents[id]?.status == .failed { throw ReaderFailure.previewProtectionUnavailable }
            try await Task.sleep(for: .milliseconds(5))
        }
        let details = "status=\(String(describing: model.documents[id]?.status)) preview=\(String(describing: model.documents[id]?.preview?.version)) rendered=\(String(describing: model.renderedVersions[id])) query=\(String(describing: model.searchState?.query)) expectedQuery=\(String(describing: query)) previous=\(String(describing: old)) url=\(String(describing: model.controller(for: id)?.webView.url)) loading=\(String(describing: model.controller(for: id)?.webView.isLoading))"
        throw NSError(domain: "Performance.Wait", code: 1, userInfo: [NSLocalizedDescriptionKey: details])
    }

    @MainActor
    private func paint(_ model: ReadingCoordinator, id: UUID) async throws {
        let view = try XCTUnwrap(model.controller(for: id)?.webView)
        let config = WKSnapshotConfiguration(); config.afterScreenUpdates = true
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NSImage, Error>) in
            view.takeSnapshot(with: config) { image, error in
                if let image { continuation.resume(returning: image) }
                else { continuation.resume(throwing: error ?? ReaderFailure.previewProtectionUnavailable) }
            }
        }
    }
}
