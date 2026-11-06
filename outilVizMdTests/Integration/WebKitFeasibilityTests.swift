import AppKit
import CryptoKit
import Markdown
import WebKit
import XCTest
@testable import outilVizMd

final class WebKitFeasibilityTests: XCTestCase {
    func testPinnedMarkdownEngineRecognizesSimpleTables() {
        let document = Document(parsing: "| Nom | Valeur |\n| --- | --- |\n| café | 42 |\n")
        XCTAssertTrue(document.children.contains { $0 is Table })
    }

    @MainActor
    func testProtectionConfigurationIsInstalledBeforeLoading() async throws {
        let configuration = try await PreviewSecurityConfiguration.make()
        XCTAssertFalse(configuration.defaultWebpagePreferences.allowsContentJavaScript)
        XCTAssertFalse(configuration.preferences.javaScriptCanOpenWindowsAutomatically)
        XCTAssertFalse(configuration.websiteDataStore.isPersistent)
        XCTAssertTrue(configuration.userContentController.userScripts.isEmpty)
        let firstNonce = ContentSecurityPolicy.newNonce()
        XCTAssertNotEqual(firstNonce, ContentSecurityPolicy.newNonce())
        let policy = try ContentSecurityPolicy.value(nonce: firstNonce)
        XCTAssertTrue(policy.contains("script-src 'none'"))
        XCTAssertTrue(policy.contains("connect-src 'none'"))
        XCTAssertTrue(policy.contains("style-src 'nonce-\(firstNonce)'"))
        XCTAssertThrowsError(try ContentSecurityPolicy.value(nonce: "injection'; url(http://example.invalid)"))
    }

    @MainActor
    func testInvalidBlockRulesFailClosed() async {
        do {
            _ = try await PreviewSecurityConfiguration.make(ruleListJSON: "invalid rules")
            XCTFail("Une configuration sans protections ne doit jamais être retournée")
        } catch {
            XCTAssertEqual(error as? ReaderFailure, .previewProtectionUnavailable)
        }
    }

    @MainActor
    func testHTTPAndHTTPSAreBlockedByContentRulesWithClientEntitlement() async throws {
        // Le délégué permissif de cette épreuve force une navigation réseau. Il vérifie
        // l’erreur de blocage du chargement, pas l’absence de connexions spéculatives.
        // La sonde de confidentialité utilise seulement le test d’affichage passif ci-dessous.
        for scheme in ["http", "https"] {
            let configuration = try await PreviewSecurityConfiguration.make()
            let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 640, height: 480), configuration: configuration)
            let probe = ContentRuleBlockingProbe()
            view.navigationDelegate = probe
            let rejected = expectation(description: "\(scheme) rejeté par les règles de contenu")
            probe.finished = { rejected.fulfill() }
            let url = try XCTUnwrap(URL(string: "\(scheme)://127.0.0.1:49183/should-not-load"))
            view.load(URLRequest(url: url))
            await fulfillment(of: [rejected], timeout: 10)
            probe.finished = nil
            let error = try XCTUnwrap(probe.failure as NSError?)
            XCTAssertEqual(error.domain, "WebKitErrorDomain")
            // Erreur WebKit de chargement bloqué par un content blocker. Une erreur de
            // connexion/certificat ou un crash ne doit pas être pris pour un blocage réussi.
            XCTAssertEqual(error.code, 104)
            view.stopLoading()
        }
    }

    @MainActor
    func testRemoteSubresourcesRemainBlockedOnLocalPageWithClientEntitlement() async throws {
        let base = try XCTUnwrap(URL(string: "outilvizmd://preview/\(UUID().uuidString)/document"))
        let nonce = ContentSecurityPolicy.newNonce()
        let policy = try ContentSecurityPolicy.value(nonce: nonce)
        let html = """
        <!doctype html><html><head><meta http-equiv="Content-Security-Policy" content="\(policy)">
        <style nonce="\(nonce)">body { background-image: url(http://127.0.0.1:49183/background); }</style>
        <link rel="stylesheet" href="http://127.0.0.1:49183/style.css"></head><body>
        <p>Page locale lisible</p><img src="http://127.0.0.1:49183/http.png" alt="Image bloquée">
        <img src="https://127.0.0.1:49183/https.png" alt="Image bloquée">
        <iframe src="http://127.0.0.1:49183/frame"></iframe></body></html>
        """
        let handler = FeasibilitySchemeHandler(url: base, html: html)
        let config = try await PreviewSecurityConfiguration.make()
        config.setURLSchemeHandler(handler, forURLScheme: "outilvizmd")
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 640, height: 480), configuration: config)
        let probe = FeasibilityNavigationProbe(baseURL: base)
        view.navigationDelegate = probe
        let loaded = expectation(description: "Page locale chargée malgré les ressources refusées")
        probe.finished = { loaded.fulfill() }
        view.load(URLRequest(url: base))
        await fulfillment(of: [loaded], timeout: 10)
        probe.finished = nil
        XCTAssertNil(probe.failure)
        XCTAssertEqual(handler.documentLoads, 1)
        view.stopLoading()
    }

    @MainActor
    func testPrivateSchemeFragmentsAndIdenticalInteractionStateWithoutJavaScript() async throws {
        let nonce = ContentSecurityPolicy.newNonce()
        let policy = try ContentSecurityPolicy.value(nonce: nonce)
        let token = UUID().uuidString
        let base = try XCTUnwrap(URL(string: "outilvizmd://preview/\(token)/document"))
        let destination = try XCTUnwrap(URL(string: base.absoluteString + "#result-1"))
        let visibleText = "mot café mot"
        let count = visibleText.components(separatedBy: "mot").count - 1
        XCTAssertEqual(count, 2)
        // Page constante de preuve technique, distincte du futur renderer de documents non fiables.
        let html = """
        <!doctype html><html lang="fr"><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="\(policy)">
        <style nonce="\(nonce)">
        body { background: #fff; color: #111; font: 20px system-ui; margin: 30px; }
        table { border-collapse: collapse; } td, th { border: 1px solid #333; padding: 8px; }
        .spacer { height: 1600px; } mark { background: #ff0; }
        </style></head><body><h1 id="titre">Titre de départ</h1>
        <table><thead><tr><th>Nom</th><th>Valeur</th></tr></thead>
        <tbody><tr><td>café</td><td>42</td></tr></tbody></table>
        <p>\(count) occurrences produites côté Swift</p><div class="spacer"></div>
        <h2 id="result-1">Résultat natif</h2><p><mark>mot</mark> café <mark>mot</mark></p>
        <div class="spacer"></div></body></html>
        """
        let handler = FeasibilitySchemeHandler(url: base, html: html)
        let config = try await PreviewSecurityConfiguration.make()
        config.setURLSchemeHandler(handler, forURLScheme: "outilvizmd")
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 640, height: 480), configuration: config)
        let probe = FeasibilityNavigationProbe(baseURL: base)
        view.navigationDelegate = probe
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.orderFront(nil)
        defer { view.stopLoading(); window.orderOut(nil); window.close() }

        let loaded = expectation(description: "Chargement du document par schéma privé")
        probe.finished = { loaded.fulfill() }
        view.load(URLRequest(url: base))
        await fulfillment(of: [loaded], timeout: 15)
        probe.finished = nil
        XCTAssertNil(probe.failure)
        guard probe.failure == nil else { return }
        XCTAssertEqual(handler.documentLoads, 1)
        let initialImage = try await snapshot(view)
        let initialPixels = try pixels(initialImage)

        let fragmentReached = expectation(description: "Fragment du résultat")
        let observation = view.observe(\.url, options: [.new]) { observed, _ in
            Task { @MainActor in
                if observed.url?.fragment == "result-1" { fragmentReached.fulfill() }
            }
        }
        view.load(URLRequest(url: destination))
        await fulfillment(of: [fragmentReached], timeout: 10)
        observation.invalidate()
        let resultImage = try await snapshot(view)
        let resultPixels = try pixels(resultImage)
        XCTAssertNotEqual(initialPixels, resultPixels, "Le fragment doit déplacer la lecture vers le résultat")

        let state = try XCTUnwrap(view.interactionState)
        let restoredConfig = try await PreviewSecurityConfiguration.make()
        restoredConfig.setURLSchemeHandler(handler, forURLScheme: "outilvizmd")
        let restoredView = WKWebView(frame: view.frame, configuration: restoredConfig)
        restoredView.navigationDelegate = probe
        window.contentView = restoredView
        let identicalLoaded = expectation(description: "Reconstruction strictement identique")
        probe.finished = { identicalLoaded.fulfill() }
        restoredView.load(URLRequest(url: base))
        await fulfillment(of: [identicalLoaded], timeout: 15)
        probe.finished = nil
        restoredView.interactionState = state
        // WebKit applique la restauration dans son processus de rendu ; attendre une image
        // identique de façon bornée plutôt que déduire le défilement du seul fragment de l’URL.
        var restoredPixels = Data()
        for _ in 0..<20 {
            restoredPixels = try pixels(await snapshot(restoredView))
            if restoredPixels == resultPixels { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(restoredPixels, resultPixels, "La reconstruction identique doit retrouver la position")
        XCTAssertNil(probe.failure)
        restoredView.stopLoading()
        for (name, image) in [("Titre et tableau", initialImage), ("Fragment du résultat", resultImage)] {
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    private func snapshot(_ view: WKWebView) async throws -> NSImage {
        let configuration = WKSnapshotConfiguration()
        configuration.afterScreenUpdates = true
        return try await withCheckedThrowingContinuation { continuation in
            view.takeSnapshot(with: configuration) { image, error in
                if let image { continuation.resume(returning: image) }
                else { continuation.resume(throwing: error ?? ReaderFailure.previewProtectionUnavailable) }
            }
        }
    }

    private func pixels(_ image: NSImage) throws -> Data {
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}

@MainActor
private final class FeasibilitySchemeHandler: NSObject, WKURLSchemeHandler {
    let url: URL
    let data: Data
    private(set) var documentLoads = 0

    init(url: URL, html: String) {
        self.url = url
        data = Data(html.utf8)
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let request = urlSchemeTask.request.url,
              request.scheme == url.scheme, request.host == url.host,
              request.path == url.path, request.query == nil else {
            urlSchemeTask.didFailWithError(ReaderFailure.previewProtectionUnavailable)
            return
        }
        documentLoads += 1
        urlSchemeTask.didReceive(URLResponse(url: request, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8"))
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Toutes les réponses sont synchrones : aucun travail ni callback ne survit à stop.
    }
}

@MainActor
private final class FeasibilityNavigationProbe: NSObject, WKNavigationDelegate {
    let baseURL: URL
    var finished: (() -> Void)?
    var failure: Error?

    init(baseURL: URL) { self.baseURL = baseURL }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        let url = navigationAction.request.url
        return url?.scheme == baseURL.scheme && url?.host == baseURL.host
            && url?.path == baseURL.path && url?.query == nil ? .allow : .cancel
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finished?() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failure = error
        finished?()
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failure = error
        finished?()
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        failure = ReaderFailure(category: .renderingFailed,
                                message: "Le processus de rendu WebKit s’est arrêté avant la fin du chargement.",
                                recoveries: [.retry], documentID: nil)
        finished?()
    }
}

/// Ce délégué de test admet volontairement la navigation loopback pour éprouver les règles
/// WebKit indépendamment de la future politique native. Il n’appartient pas à l’application.
@MainActor
private final class ContentRuleBlockingProbe: NSObject, WKNavigationDelegate {
    var failure: Error?
    var finished: (() -> Void)?

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url, url.host == "127.0.0.1", url.port == 49183,
              ["http", "https"].contains(url.scheme) else { return .cancel }
        return .allow
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finished?() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failure = error
        finished?()
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failure = error
        finished?()
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        failure = ReaderFailure.previewProtectionUnavailable
        finished?()
    }
}
