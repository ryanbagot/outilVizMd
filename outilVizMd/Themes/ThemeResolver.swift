import Foundation

struct ResolvedTheme: Sendable {
    let dark: Bool
    let palette: ReadingPalette
    var hasLowContrast: Bool {
        ContrastCalculator.ratio(palette.text, palette.background) < 4.5 || ContrastCalculator.ratio(palette.link, palette.background) < 4.5
    }
}

enum ThemeResolver {
    static func resolve(_ preferences: RenderPreferences, systemDark: Bool) -> ResolvedTheme {
        let dark = preferences.theme == .dark || (preferences.theme == .system && systemDark)
        return ResolvedTheme(dark: dark, palette: dark ? preferences.darkPalette : preferences.lightPalette)
    }
}
