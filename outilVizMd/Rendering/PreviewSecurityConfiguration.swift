import CryptoKit
import Foundation
import WebKit

enum ContentSecurityPolicy {
    static func newNonce() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    /// Le nonce vient exclusivement de l’app ; aucune valeur du document ne devient du CSS.
    static func value(nonce: String) throws -> String {
        guard nonce.count == 32, nonce.utf8.allSatisfy({
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }) else { throw ReaderFailure.previewProtectionUnavailable }
        return "default-src 'none'; script-src 'none'; connect-src 'none'; "
            + "frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; "
            + "img-src outilvizmd:; style-src 'nonce-\(nonce)'; style-src-attr 'none'; "
            + "font-src 'none'; media-src 'none'"
    }
}

@MainActor
enum PreviewSecurityConfiguration {
    /// Le JSON injectable permet de vérifier l’échec fermé. Aucune configuration partiellement
    /// protégée ne sort de cette méthode : la compilation et l’installation précèdent le retour.
    static func make(ruleListJSON: String? = nil) async throws -> WKWebViewConfiguration {
        let rules: String
        if let ruleListJSON {
            rules = ruleListJSON
        } else {
            guard let url = Bundle.main.url(forResource: "NetworkBlockRules", withExtension: "json") else {
                throw ReaderFailure.previewProtectionUnavailable
            }
            rules = try String(contentsOf: url, encoding: .utf8)
        }
        let hash = SHA256.hash(data: Data(rules.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        let ruleList: WKContentRuleList
        do {
            guard let compiled = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "outilVizMd.network.\(hash)", encodedContentRuleList: rules
            ) else { throw ReaderFailure.previewProtectionUnavailable }
            ruleList = compiled
        } catch {
            throw ReaderFailure.previewProtectionUnavailable
        }

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.websiteDataStore = .nonPersistent()
        let controller = WKUserContentController()
        controller.add(ruleList)
        configuration.userContentController = controller
        return configuration
    }
}
