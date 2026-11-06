import Foundation
import CoreFoundation

struct PreferencesLoadResult: Sendable {
    let preferences: RenderPreferences
    let warning: ReaderFailure?
}

actor PreferencesStore {
    let url: URL
    private var savedRevision: UInt64 = 0
    private let availableFonts: Set<String>
    private let write: @Sendable (Data, URL) throws -> Void

    init(url: URL, availableFonts: Set<String>, write: @escaping @Sendable (Data, URL) throws -> Void = { bytes, url in
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url, options: .atomic)
    }) {
        self.url = url
        self.availableFonts = availableFonts
        self.write = write
    }

    func load() -> PreferencesLoadResult {
        guard FileManager.default.fileExists(atPath: url.path) else { return PreferencesLoadResult(preferences: .defaults, warning: nil) }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return PreferencesLoadResult(preferences: .defaults, warning: Self.invalid) }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 64 * 1024 + 1), data.count <= 64 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Self.number(object["schemaVersion"]) == 1 else {
            return PreferencesLoadResult(preferences: .defaults, warning: Self.invalid)
        }
        var prefs = RenderPreferences.defaults
        var invalid = false
        if let value = object["theme"] { if let raw = value as? String, let theme = RenderPreferences.Theme(rawValue: raw) { prefs.theme = theme } else { invalid = true } }
        if let value = object["style"] { if let raw = value as? String, let style = RenderPreferences.Style(rawValue: raw) { prefs.style = style } else { invalid = true } }
        if let value = object["fontSize"] { if let size = Self.number(value), prefs.setFontSize(size) { } else { invalid = true } }
        if let value = object["fontIdentifier"], !(value is NSNull) {
            if let font = value as? String, availableFonts.contains(font) { prefs.selectFont(font, availableIdentifiers: availableFonts) }
            else { invalid = true }
        }
        func palette(_ key: String, fallback: ReadingPalette) -> ReadingPalette {
            guard let value = object[key] else { return fallback }
            guard let values = value as? [String: Any] else { invalid = true; return fallback }
            func color(_ key: String, _ fallback: SRGBColor) -> SRGBColor {
                guard let raw = values[key] else { return fallback }
                guard let fields = raw as? [String: Any], let r = Self.number(fields["red"]), let g = Self.number(fields["green"]), let b = Self.number(fields["blue"]), let color = SRGBColor(red: r, green: g, blue: b) else { invalid = true; return fallback }
                return color
            }
            return ReadingPalette(text: color("text", fallback.text), background: color("background", fallback.background), link: color("link", fallback.link))
        }
        prefs.lightPalette = palette("lightPalette", fallback: .light)
        prefs.darkPalette = palette("darkPalette", fallback: .dark)
        return PreferencesLoadResult(preferences: prefs, warning: invalid ? Self.invalid : nil)
    }

    func save(_ prefs: RenderPreferences, revision: UInt64? = nil) throws {
        if let revision { guard revision >= savedRevision else { return }; savedRevision = revision }
        func color(_ c: SRGBColor) -> [String: Double] { ["red": c.red, "green": c.green, "blue": c.blue] }
        func palette(_ p: ReadingPalette) -> [String: Any] { ["text": color(p.text), "background": color(p.background), "link": color(p.link)] }
        let object: [String: Any] = ["schemaVersion": 1, "theme": prefs.theme.rawValue, "fontSize": prefs.fontSize,
            "fontIdentifier": prefs.fontIdentifier as Any? ?? NSNull(), "style": prefs.style.rawValue,
            "lightPalette": palette(prefs.lightPalette), "darkPalette": palette(prefs.darkPalette)]
        do { try write(JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted]), url) }
        catch { throw Self.notSaved }
    }

    private static func number(_ value: Any?) -> Double? {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite else { return nil }
        return value.doubleValue
    }

    func reset() throws { try save(.defaults) }
    static let invalid = ReaderFailure(category: .preferencesNotSaved, message: "Certains réglages enregistrés sont invalides. Les valeurs sûres ont été rétablies ; les autres choix sont conservés.", recoveries: [.resetPreferences], documentID: nil)
    static let notSaved = ReaderFailure(category: .preferencesNotSaved, message: "Les réglages sont appliqués, mais n’ont pas pu être enregistrés. Ils restent disponibles pendant cette session.", recoveries: [.resetPreferences], documentID: nil)
}
