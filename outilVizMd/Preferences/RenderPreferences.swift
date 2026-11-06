import Foundation

struct SRGBColor: Codable, Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init?(red: Double, green: Double, blue: Double) {
        guard [red, green, blue].allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return nil }
        self.red = red
        self.green = green
        self.blue = blue
    }

    private enum CodingKeys: CodingKey { case red, green, blue }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let red = try values.decode(Double.self, forKey: .red)
        let green = try values.decode(Double.self, forKey: .green)
        let blue = try values.decode(Double.self, forKey: .blue)
        guard let color = Self(red: red, green: green, blue: blue) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Couleur sRGB hors limites"))
        }
        self = color
    }

    private init(validRed: Double, green: Double, blue: Double) {
        red = validRed
        self.green = green
        self.blue = blue
    }

    static let lightText = Self(validRed: 0.10, green: 0.11, blue: 0.13)
    static let lightBackground = Self(validRed: 1, green: 1, blue: 1)
    static let lightLink = Self(validRed: 0.04, green: 0.25, blue: 0.65)
    static let darkText = Self(validRed: 0.93, green: 0.94, blue: 0.95)
    static let darkBackground = Self(validRed: 0.08, green: 0.09, blue: 0.11)
    static let darkLink = Self(validRed: 0.45, green: 0.70, blue: 1)
}

struct ReadingPalette: Codable, Equatable, Sendable {
    var text: SRGBColor
    var background: SRGBColor
    var link: SRGBColor

    static let light = Self(text: .lightText, background: .lightBackground, link: .lightLink)
    static let dark = Self(text: .darkText, background: .darkBackground, link: .darkLink)
}

struct RenderPreferences: Equatable, Sendable {
    enum Theme: String, Codable, CaseIterable, Sendable { case system, light, dark }
    enum Style: String, Codable, CaseIterable, Sendable { case standard, compact, airy }

    let schemaVersion = 1
    var theme: Theme = .system
    /// nil désigne la police système ; tout identifiant externe est validé dans le catalogue local.
    private(set) var fontIdentifier: String?
    private(set) var fontSize: Double = 16
    var style: Style = .standard
    var lightPalette: ReadingPalette = .light
    var darkPalette: ReadingPalette = .dark

    static let defaults = Self()

    @discardableResult
    mutating func setFontSize(_ size: Double) -> Bool {
        guard size.isFinite, (12...32).contains(size) else { return false }
        fontSize = size
        return true
    }

    mutating func selectFont(_ identifier: String?, availableIdentifiers: Set<String>) {
        fontIdentifier = identifier.flatMap { availableIdentifiers.contains($0) ? $0 : nil }
    }
}
