import XCTest
@testable import outilVizMd

final class ThemeResolverTests: XCTestCase {
    func testSystemAndExplicitThemesUseSeparatePalettesAndContrast() throws {
        var prefs = RenderPreferences.defaults
        XCTAssertEqual(ThemeResolver.resolve(prefs, systemDark: false).palette, .light)
        XCTAssertEqual(ThemeResolver.resolve(prefs, systemDark: true).palette, .dark)
        prefs.theme = .light
        XCTAssertEqual(ThemeResolver.resolve(prefs, systemDark: true).palette, .light)
        let black = try XCTUnwrap(SRGBColor(red: 0, green: 0, blue: 0))
        let white = try XCTUnwrap(SRGBColor(red: 1, green: 1, blue: 1))
        XCTAssertEqual(ContrastCalculator.ratio(black, white), 21, accuracy: 0.001)
        XCTAssertEqual(ContrastCalculator.ratio(black, black), 1)
        XCTAssertFalse(prefs.setFontSize(.nan)); XCTAssertFalse(prefs.setFontSize(33))
        XCTAssertNil(SRGBColor(red: .infinity, green: 0, blue: 0))
    }
}
