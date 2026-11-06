import Foundation
import WebKit

@MainActor
final class PreviewSchemeHandler: NSObject, WKURLSchemeHandler {
    let store: PreviewResourceStore
    init(store: PreviewResourceStore) { self.store = store }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        do {
            guard let url = urlSchemeTask.request.url else { throw PreviewResourceStore.unavailable }
            let resource = try store.resource(for: url)
            urlSchemeTask.didReceive(URLResponse(url: url, mimeType: resource.mime.rawValue, expectedContentLength: resource.bytes.count, textEncodingName: resource.mime == .html ? "utf-8" : nil))
            urlSchemeTask.didReceive(resource.bytes)
            urlSchemeTask.didFinish()
        } catch { urlSchemeTask.didFailWithError(error) }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // MainActor sérialise start/stop et les réponses sont synchrones : aucun callback différé.
    }
}
