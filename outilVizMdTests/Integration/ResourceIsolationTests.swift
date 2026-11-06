import XCTest
import WebKit
@testable import outilVizMd

final class ResourceIsolationTests: XCTestCase {
    @MainActor
    func testWrongPreviewTokenAndMalformedResourcePathsCannotReadAnyBytes() throws {
        let store = PreviewResourceStore()
        let token = UUID(), id = UUID()
        let resource = ResourceSnapshot(id: id, previewToken: UUID(), bytes: Data([1, 2, 3]), mime: .png, pixelWidth: 1, pixelHeight: 1, alternativeText: "")
        let preview = PreviewSnapshot(version: PresentationVersion(documentID: UUID(), sourceGeneration: 1, presentationGeneration: 1), html: "", token: token, resources: [resource])
        store.install(preview)
        for path in ["resource/\(id.uuidString)", "resource/\(UUID().uuidString)", "resource/../document", "document?path=/etc/passwd", "%64ocument"] {
            let url = try XCTUnwrap(URL(string: "outilvizmd://preview/\(token.uuidString)/\(path)"))
            XCTAssertThrowsError(try store.resource(for: url))
        }
    }
}

private final class RecordingSchemeTask: NSObject, WKURLSchemeTask {
    let request: URLRequest
    var callbacks = 0
    init(_ url: URL) { request = URLRequest(url: url) }
    func didReceive(_ response: URLResponse) { callbacks += 1 }
    func didReceive(_ data: Data) { callbacks += 1 }
    func didFinish() { callbacks += 1 }
    func didFailWithError(_ error: Error) { callbacks += 1 }
}

extension ResourceIsolationTests {
    @MainActor
    func testRevocationAndStopLeaveNoDeferredCallbackOrDiskFallback() async throws {
        let store = PreviewResourceStore(), token = UUID()
        let preview = PreviewSnapshot(version: PresentationVersion(documentID: UUID(), sourceGeneration: 1, presentationGeneration: 1), html: "Texte local", token: token, resources: [])
        store.install(preview)
        let url = try XCTUnwrap(URL(string: "outilvizmd://preview/\(token.uuidString)/document"))
        let controller = try await PreviewController.make(store: store)
        let handler = PreviewSchemeHandler(store: store)
        let task = RecordingSchemeTask(url)
        handler.webView(controller.webView, start: task)
        XCTAssertEqual(task.callbacks, 3)
        handler.webView(controller.webView, stop: task)
        await Task.yield()
        XCTAssertEqual(task.callbacks, 3)
        store.revoke(token)
        XCTAssertThrowsError(try store.resource(for: url))
        let revoked = RecordingSchemeTask(url)
        handler.webView(controller.webView, start: revoked)
        XCTAssertEqual(revoked.callbacks, 1)
        controller.close()
    }

    func testInvalidAndExternalImagesCannotProduceAResource() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let invalid = try corpus.write(Data("<svg onload='alert(1)'/>".utf8), to: "invalid.png")
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(corpus.root, kind: .directory)
        let loader = LocalImageLoader(access: access)
        do { _ = try await loader.load(invalid, grantID: grant.id, token: UUID(), alternativeText: "Image"); XCTFail("SVG déguisé accepté") } catch { }
        let outside = URL(fileURLWithPath: "/etc/passwd")
        do { _ = try await loader.load(outside, grantID: grant.id, token: UUID(), alternativeText: "Image"); XCTFail("Image hors périmètre acceptée") } catch { }
    }
}
