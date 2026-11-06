import AppKit
import SwiftUI
import WebKit

@MainActor
final class PreviewController: NSObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    private let store: PreviewResourceStore
    private var preview: PreviewSnapshot?
    private var tokens: Set<UUID> = []
    private var displayedToken: UUID?
    private var expectedNavigation: WKNavigation?
    var onNavigation: ((PreviewNavigation) -> Void)?
    var onFailure: ((ReaderFailure) -> Void)?
    var onReady: ((PresentationVersion) -> Void)?

    static func make(store: PreviewResourceStore) async throws -> PreviewController {
        let config = try await PreviewSecurityConfiguration.make()
        config.setURLSchemeHandler(PreviewSchemeHandler(store: store), forURLScheme: "outilvizmd")
        return PreviewController(webView: WKWebView(frame: .zero, configuration: config), store: store)
    }

    private init(webView: WKWebView, store: PreviewResourceStore) {
        self.webView = webView
        self.store = store
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.setAccessibilityLabel("Aperçu du document Markdown")
    }

    func load(_ snapshot: PreviewSnapshot, fragment: String? = nil) {
        guard snapshot.token != preview?.token else { return }
        for token in tokens where token != displayedToken { store.revoke(token) }
        tokens = displayedToken.map { [$0] } ?? []
        store.install(snapshot)
        tokens.insert(snapshot.token)
        preview = snapshot
        var components = URLComponents()
        components.scheme = "outilvizmd"
        components.host = "preview"
        components.path = "/\(snapshot.token.uuidString)/document"
        if let fragment, snapshot.fragments.contains(fragment) { components.fragment = fragment }
        guard let url = components.url else { onFailure?(.previewProtectionUnavailable); return }
        expectedNavigation = webView.load(URLRequest(url: url))
    }

    func jump(to fragment: String) {
        guard let preview, preview.fragments.contains(fragment), let current = webView.url,
              var components = URLComponents(url: current, resolvingAgainstBaseURL: false) else { return }
        components.path = "/\(preview.token.uuidString)/document"
        components.fragment = fragment
        if let url = components.url { webView.load(URLRequest(url: url)) }
    }

    var semanticFragment: String? {
        guard let fragment = webView.url?.fragment, preview?.fragments.contains(fragment) == true, !fragment.hasPrefix("search-") else { return nil }
        return fragment
    }

    func close() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        tokens.forEach { store.revoke($0) }
        tokens.removeAll()
        preview = nil
        onNavigation = nil
        onFailure = nil
        onReady = nil
        expectedNavigation = nil
        displayedToken = nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let preview, let url = action.request.url, action.targetFrame?.isMainFrame == true, !action.shouldPerformDownload else { return .cancel }
        let decision = NavigationPolicy.decide(url, explicitClick: action.navigationType == .linkActivated, preview: preview)
        switch decision {
        case .allowDocument: return .allow
        case let .fragment(fragment): jump(to: fragment)
        case .openExternal, .openLocal: onNavigation?(decision)
        case .refuse:
            if action.navigationType == .linkActivated {
                onFailure?(ReaderFailure(category: .accessDenied, message: "Ce lien est bloqué ou n’est plus disponible.", recoveries: [.selectFile, .selectFolder], documentID: preview.version.documentID))
            }
        }
        return .cancel
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        response.canShowMIMEType && response.response.mimeType == "text/html" ? .allow : .cancel
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation === expectedNavigation, let preview, let url = webView.url, let parts = PreviewResourceStore.parts(url), UUID(uuidString: parts[0]) == preview.token else { return }
        for token in tokens where token != preview.token { store.revoke(token) }
        tokens = [preview.token]
        displayedToken = preview.token
        if navigation === expectedNavigation { onReady?(preview.version) }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { if navigation === expectedNavigation { report(error) } }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { if navigation === expectedNavigation { report(error) } }
    private func report(_ error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { onFailure?(.previewProtectionUnavailable) }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        onFailure?(ReaderFailure(category: .renderingFailed, message: "L’aperçu s’est arrêté. Réessayez pour le recharger.", recoveries: [.retry, .close], documentID: preview?.version.documentID))
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { nil }
}

struct PreviewWebView: NSViewRepresentable {
    let controller: PreviewController
    func makeNSView(context: Context) -> WKWebView { controller.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) { }
}
