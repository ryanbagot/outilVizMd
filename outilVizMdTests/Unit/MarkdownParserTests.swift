import XCTest
@testable import outilVizMd

final class MarkdownParserTests: XCTestCase {
    func testSupportedStructureProjectionAndDuplicateAnchors() async throws {
        let parser = MarkdownParser()
        let text = "# Titre\n\n## Titre\n\n**gras** et *café* `code`\n\n| Nom | Valeur |\n| --- | --- |\n| café | 42 |\n\n<script>danger()</script>\n"
        let parsed = await parser.parse(text: text, documentID: UUID(), generation: 1)
        XCTAssertEqual(parsed.headings.map(\.fragment), ["titre", "titre-2"])
        XCTAssertTrue(parsed.visibleText.text.contains("gras et café code"))
        XCTAssertTrue(parsed.visibleText.text.contains("café"))
        XCTAssertTrue(parsed.visibleText.text.contains("<script>danger()</script>"))
        XCTAssertFalse(parsed.visibleText.text.contains("**gras**"))
        XCTAssertFalse(parsed.visibleText.runs.isEmpty)
    }

    func testAllCorpusElementsAndMalformedMarkdownRemainReadable() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        try corpus.copyFixtures()
        let parser = MarkdownParser()
        for name in ["CommonMark.md", "Malformed.md", "Empty.md"] {
            let text = try String(contentsOf: corpus.url(name), encoding: .utf8)
            let parsed = await parser.parse(text: text, documentID: UUID(), generation: 1)
            if !text.isEmpty { XCTAssertFalse(parsed.visibleText.text.isEmpty) }
        }
    }
}
