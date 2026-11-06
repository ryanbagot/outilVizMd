import XCTest
@testable import outilVizMd

final class ThemePresentationTests: XCTestCase {
    @MainActor
    func testThemeSearchRapidChangesKeepLatestPreferencesAndSource() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let url = try corpus.write(Data("# Lecture\n\nLecture et confort.\n".utf8), to: "doc.md")
        let bytes = try Data(contentsOf: url)
        let store = PreferencesStore(url: corpus.root.appendingPathComponent("prefs.json"), availableFonts: ["Helvetica"])
        let model = ReadingCoordinator(preferencesStore: store)
        await model.loadPreferences()
        let grant = try await model.files.authorizeSelectedURL(url, kind: .file)
        await model.open(url, grantID: grant.id)
        let id = try XCTUnwrap(model.activeDocumentID)
        try await wait { model.documents[id]?.status == .ready }
        model.presentSearch(); model.updateSearch("Lecture")
        for index in 0..<10 {
            var prefs = RenderPreferences.defaults
            prefs.theme = index.isMultiple(of: 2) ? .light : .dark
            prefs.style = .airy; prefs.setFontSize(23)
            prefs.selectFont("Helvetica", availableIdentifiers: ["Helvetica"])
            prefs.darkPalette.link = .lightLink
            model.updatePreferences(prefs)
        }
        try await wait { model.searchState?.total == 2 && model.documents[id]?.preview?.html.contains("font-size:23.0pt") == true }
        XCTAssertEqual(model.preferences.theme, .dark)
        XCTAssertTrue(try XCTUnwrap(model.documents[id]?.preview?.html).contains("color-scheme:dark"))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        model.close(id)
        let failing = PreferencesStore(url: corpus.root.appendingPathComponent("failure.json"), availableFonts: [], write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        let second = ReadingCoordinator(preferencesStore: failing)
        var prefs = RenderPreferences.defaults; prefs.setFontSize(21)
        second.updatePreferences(prefs)
        try await wait { second.preferencesWarning != nil }
        XCTAssertEqual(second.preferences.fontSize, 21)
    }
    @MainActor
    private func wait(_ predicate: () -> Bool) async throws {
        for _ in 0..<200 { if predicate() { return }; try await Task.sleep(for: .milliseconds(25)) }
        XCTFail("Présentation non publiée")
    }
}
