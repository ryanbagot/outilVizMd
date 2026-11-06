import XCTest
@testable import outilVizMd

final class NoAutomaticNetworkTests: XCTestCase {
    @MainActor
    func testProductionRenderingNeverPublishesNetworkResourcesOrOpensBrowser() async throws {
        let source = """
        # Document local
        ![Image refusée](\(NetworkProbe.endpoint)/image.png)
        [Lien explicite](\(NetworkProbe.endpoint)/page)
        <script>fetch('\(NetworkProbe.endpoint)/script')</script>
        <iframe src="\(NetworkProbe.endpoint)/frame"></iframe>
        <style>body{background:url(\(NetworkProbe.endpoint)/css)}</style>
        Le reste reste lisible.
        """
        let parsed = await MarkdownParser().parse(text: source, documentID: UUID(), generation: 1)
        let version = PresentationVersion(documentID: parsed.documentID, sourceGeneration: 1, presentationGeneration: 1)
        let preview = try await SafeHTMLRenderer(access: AuthorizedFileAccess()).render(parsed, documentURL: URL(fileURLWithPath: "/unused.md"), grantID: UUID(), preferences: .defaults, version: version)
        XCTAssertTrue(preview.resources.isEmpty)
        XCTAssertFalse(preview.html.contains("src=\"http"))
        XCTAssertFalse(preview.html.contains("href=\"http"))
        let controller = try await PreviewController.make(store: PreviewResourceStore())
        let ready = expectation(description: "Page hostile rendue avec le contrôleur de production")
        controller.onReady = { _ in ready.fulfill() }
        controller.onFailure = { failure in XCTFail(failure.message); ready.fulfill() }
        controller.onNavigation = { _ in XCTFail("Une lecture passive ne doit rien ouvrir") }
        controller.load(preview)
        await fulfillment(of: [ready], timeout: 15)
        controller.onReady = nil
        try await Task.sleep(for: .milliseconds(250))
        controller.close()
    }
}
