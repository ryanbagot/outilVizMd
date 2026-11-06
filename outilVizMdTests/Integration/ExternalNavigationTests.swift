import XCTest
@testable import outilVizMd

final class ExternalNavigationTests: XCTestCase {
    func testUnknownTokensPopupsAndNonHTTPDestinationsAreRejected() throws {
        let token = UUID(), link = UUID()
        let executable = try XCTUnwrap(URL(string: "mailto:person@example.invalid"))
        let preview = PreviewSnapshot(version: PresentationVersion(documentID: UUID(), sourceGeneration: 1, presentationGeneration: 1), html: "", token: token, resources: [], links: [link: .web(executable)])
        for raw in ["outilvizmd://preview/\(token.uuidString)/link/\(link.uuidString)", "outilvizmd://preview/\(UUID().uuidString)/document", "https://example.invalid/", "file:///etc/passwd", "javascript:alert(1)"] {
            XCTAssertEqual(NavigationPolicy.decide(try XCTUnwrap(URL(string: raw)), explicitClick: true, preview: preview), .refuse)
        }
    }
    @MainActor
    func testSystemOpenerIsOnlyCalledForValidatedExplicitDecision() throws {
        var opened: [URL] = []
        let model = ReadingCoordinator(openExternal: { opened.append($0) })
        model.navigate(.refuse)
        XCTAssertTrue(opened.isEmpty)
        model.navigate(.openExternal(try XCTUnwrap(URL(string: "javascript:alert(1)"))))
        XCTAssertTrue(opened.isEmpty)
        let target = try XCTUnwrap(URL(string: "https://example.invalid/"))
        model.navigate(.openExternal(target))
        XCTAssertEqual(opened, [target])
    }

}
