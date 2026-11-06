import XCTest
@testable import outilVizMd

/// Le scénario n’utilise que des ressources locales. Une exécution avec connexion physique
/// coupée reste une preuve distincte : ce test ne modifie pas les interfaces réseau du Mac.
final class ReadOnlyOfflineRegressionTests: XCTestCase {
    func testAllLocalServicesPreserveCorpusBytesAndLocations() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        try corpus.copyFixtures()
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: corpus.root, includingPropertiesForKeys: [.isRegularFileKey]))
        let urls = enumerator.compactMap { $0 as? URL }.filter { ["md", "markdown"].contains($0.pathExtension.lowercased()) }
        let originals = try urls.map { try ReferenceSource($0) }
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(corpus.root, kind: .directory)
        let reader = LocalDocumentReader(access: access), parser = MarkdownParser(), renderer = SafeHTMLRenderer(access: access)
        for url in urls {
            let handle = try await access.handle(for: url, grantID: grant.id)
            do {
                let snapshot = try await reader.read(handle: handle, generation: 1)
                let parsed = await parser.parse(snapshot)
                let version = PresentationVersion(documentID: handle.id, sourceGeneration: 1, presentationGeneration: 1)
                let preview = try await renderer.render(parsed, documentURL: url, grantID: grant.id, preferences: .defaults, version: version)
                let matches = SearchIndexer.matches("lecture", in: VisibleTextIndex(try XCTUnwrap(preview.visibleText)))
                let search = SearchState(documentID: handle.id, sourceGeneration: 1, queryGeneration: 1, query: "lecture", matches: matches, currentIndex: 0)
                var prefs = RenderPreferences.defaults; prefs.theme = .dark; prefs.style = .compact; prefs.setFontSize(20)
                _ = try await renderer.render(parsed, documentURL: url, grantID: grant.id, preferences: prefs, version: version, search: search, reusing: preview)
            } catch {
                XCTAssertEqual(url.lastPathComponent, "InvalidUTF8.md", "Seul le fixture UTF-8 invalide doit être refusé")
            }
        }
        let storeURL = try corpus.url("settings/preferences.json")
        let store = PreferencesStore(url: storeURL, availableFonts: [])
        try await store.save(.defaults)
        for _ in 0..<3 { _ = await PreferencesStore(url: storeURL, availableFonts: []).load() }
        for (reference, url) in zip(originals, urls) { try assertSourcePreserved(reference, at: url) }
        _ = await access.release(grant.id)
    }
}
