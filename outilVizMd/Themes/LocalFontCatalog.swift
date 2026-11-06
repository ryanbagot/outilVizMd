import AppKit

@MainActor
enum LocalFontCatalog {
    static var identifiers: [String] { NSFontManager.shared.availableFontFamilies.sorted { $0.localizedStandardCompare($1) == .orderedAscending } }
    static func preferencesURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        var directory = base.appendingPathComponent("outilVizMd", isDirectory: true)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"), let id = ProcessInfo.processInfo.environment["OUTILVIZMD_TEST_PREFERENCES_ID"], UUID(uuidString: id) != nil {
            directory = directory.appendingPathComponent("Tests/\(id)", isDirectory: true)
        }
        #endif
        return directory.appendingPathComponent("preferences.json")
    }
}
