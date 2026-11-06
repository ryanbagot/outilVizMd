import XCTest
@testable import outilVizMd

final class PreferencesStoreTests: XCTestCase {
    func testRoundTripThreeReopensAndDurableReset() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let url = corpus.root.appendingPathComponent("store/preferences.json")
        var prefs = RenderPreferences.defaults
        prefs.theme = .dark; prefs.style = .airy
        prefs.setFontSize(23)
        prefs.selectFont("Helvetica", availableIdentifiers: ["Helvetica"])
        let store = PreferencesStore(url: url, availableFonts: ["Helvetica"])
        try await store.save(prefs)
        for _ in 0..<3 {
            let loaded = await PreferencesStore(url: url, availableFonts: ["Helvetica"]).load()
            XCTAssertEqual(loaded.preferences, prefs)
            XCTAssertNil(loaded.warning)
        }
        let bytes = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(bytes.contains("grant")); XCTAssertFalse(bytes.contains("document"))
        try await store.reset()
        let reset = await store.load()
        XCTAssertEqual(reset.preferences, .defaults)
    }

    func testInvalidFieldsFallBackIndividuallyAndStorageFailureSurfaces() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let url = try corpus.write(Data("{\"schemaVersion\":1,\"theme\":\"dark\",\"fontSize\":999,\"fontIdentifier\":\"missing\",\"style\":\"airy\",\"lightPalette\":{\"text\":{\"red\":-1,\"green\":0,\"blue\":0}}}".utf8), to: "prefs.json")
        let loaded = await PreferencesStore(url: url, availableFonts: []).load()
        XCTAssertEqual(loaded.preferences.theme, .dark)
        XCTAssertEqual(loaded.preferences.style, .airy)
        XCTAssertEqual(loaded.preferences.fontSize, 16)
        XCTAssertNil(loaded.preferences.fontIdentifier)
        XCTAssertNotNil(loaded.warning)
        for text in ["{\"schemaVersion\":true}", "invalid JSON", "{\"schemaVersion\":999,\"theme\":\"dark\"}"] {
            try Data(text.utf8).write(to: url)
            let invalid = await PreferencesStore(url: url, availableFonts: []).load()
            XCTAssertEqual(invalid.preferences, .defaults)
            XCTAssertNotNil(invalid.warning)
        }
        let broken = PreferencesStore(url: url, availableFonts: [], write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        do { try await broken.save(.defaults); XCTFail("Écriture impossible non remontée") } catch { }
    }
}
