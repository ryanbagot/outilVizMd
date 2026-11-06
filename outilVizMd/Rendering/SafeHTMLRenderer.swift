import Foundation

actor SafeHTMLRenderer {
    let access: AuthorizedFileAccess
    private let imageLoader: LocalImageLoader
    init(access: AuthorizedFileAccess) {
        self.access = access
        imageLoader = LocalImageLoader(access: access)
    }

    func render(_ parsed: ParsedDocument, documentURL: URL, grantID: UUID, preferences: RenderPreferences,
                version: PresentationVersion, search: SearchState? = nil, reusing previous: PreviewSnapshot? = nil) async throws -> PreviewSnapshot {
        let token = UUID()
        var images: [Int: ResourceSnapshot] = [:]
        var loadedURLs: [URL: ResourceSnapshot] = [:]
        var budget = 64 * 1_024 * 1_024
        var imageNodes: [MarkdownNode] = []
        func collect(_ node: MarkdownNode) {
            if case .image = node.kind { imageNodes.append(node) }
            node.children.forEach(collect)
        }
        collect(parsed.root)
        for node in imageNodes.prefix(256) {
            try Task.checkCancellation()
            guard case let .local(url) = Self.link(node.destination ?? "", relativeTo: documentURL), url.fragment == nil else { continue }
            do {
                let image: ResourceSnapshot
                if let loaded = loadedURLs[url] { image = loaded }
                else if let previous, previous.version.documentID == version.documentID, previous.version.sourceGeneration == version.sourceGeneration, let old = previous.imageResources[node.id] {
                    image = ResourceSnapshot(id: old.id, previewToken: token, bytes: old.bytes, mime: old.mime, pixelWidth: old.pixelWidth, pixelHeight: old.pixelHeight, alternativeText: old.alternativeText)
                } else { image = try await imageLoader.load(url, grantID: grantID, token: token, alternativeText: node.text) }
                let decoded = (image.pixelWidth ?? 0) * (image.pixelHeight ?? 0) * 4
                guard decoded <= budget, image.bytes.count <= budget else { continue }
                if loadedURLs[url] == nil { budget -= max(decoded, image.bytes.count) }
                loadedURLs[url] = image
                images[node.id] = image
            } catch is CancellationError { throw CancellationError() }
            catch { /* L’image indisponible ne bloque pas le document. */ }
        }
        let visible = VisibleTextProjector.projectWithNodes(parsed.root, loadedImages: Set(images.keys))
        let fragmentMap = Dictionary(parsed.headings.map { ($0.nodeID, $0.fragment) }, uniquingKeysWith: { a, _ in a })
        var fragments = Set(parsed.headings.map(\.fragment))
        if let search { fragments.formUnion(search.matches.indices.map { "search-\($0)" }) }
        let markup = SearchMarkup(search)
        var links: [UUID: PreviewLink] = [:]
        func emit(_ node: MarkdownNode, header: Bool = false) -> String {
            func children() -> String { node.children.map { emit($0, header: header) }.joined() }
            switch node.kind {
            case .document: return children()
            case .text: return markup.emit(visible.values[node.id] ?? VisibleTextProjector.inlineText(node.text), nodeID: node.id)
            case .paragraph: return "<p>\(children())</p>"
            case let .heading(level):
                let level = min(6, max(1, level))
                return "<h\(level) id=\"\(Self.escape(fragmentMap[node.id] ?? "titre-\(node.id)"))\">\(children())</h\(level)>"
            case .emphasis: return "<em>\(children())</em>"
            case .strong: return "<strong>\(children())</strong>"
            case .inlineCode: return "<code>\(markup.emit(node.text, nodeID: node.id))</code>"
            case .codeBlock: return "<pre><code>\(markup.emit(node.text, nodeID: node.id))</code></pre>"
            case let .list(ordered, start): return ordered ? "<ol start=\"\(max(1, start))\">\(children())</ol>" : "<ul>\(children())</ul>"
            case .listItem: return "<li>\(children())</li>"
            case .blockQuote: return "<blockquote>\(children())</blockquote>"
            case .softBreak: return markup.emit(visible.values[node.id] ?? " ", nodeID: node.id)
            case .hardBreak: return "<br>"
            case .thematicBreak: return "<hr>"
            case .rawHTMLLiteral: return "<span class=\"literal-html\">\(markup.emit(node.text, nodeID: node.id))</span>"
            case .table:
                let head = node.children.first.map { "<thead>\(emit($0, header: true))</thead>" } ?? ""
                return "<div class=\"table-scroll\"><table>" + head + "<tbody>" + node.children.dropFirst().map { emit($0) }.joined() + "</tbody></table></div>"
            case .tableRow: return "<tr>\(children())</tr>"
            case .tableCell: return header ? "<th>\(children())</th>" : "<td>\(children())</td>"
            case .image:
                if let image = images[node.id] {
                    return "<img src=\"outilvizmd://preview/\(token.uuidString)/resource/\(image.id.uuidString)\" alt=\"\(Self.escape(node.text))\">"
                }
                return "<span class=\"unavailable\">\(markup.emit(VisibleTextProjector.unavailableImageText(node), nodeID: node.id))</span>"
            case .link:
                let id = UUID()
                var target = Self.link(node.destination ?? "", relativeTo: documentURL)
                if case let .fragment(fragment) = target, !fragments.contains(fragment) { target = .refused }
                links[id] = target
                return "<a href=\"outilvizmd://preview/\(token.uuidString)/link/\(id.uuidString)\">\(children())</a>"
            }
        }
        let content = emit(parsed.root)
        let nonce = ContentSecurityPolicy.newNonce()
        let policy = try ContentSecurityPolicy.value(nonce: nonce)
        let baseURL = Bundle.main.url(forResource: "ReaderBase", withExtension: "css")
        let baseCSS = try baseURL.map { try String(contentsOf: $0, encoding: .utf8) } ?? "body { font: 16px system-ui; }"
        let html = "<!doctype html><html lang=\"fr\"><head><meta charset=\"utf-8\"><meta http-equiv=\"Content-Security-Policy\" content=\"\(Self.escape(policy))\"><meta name=\"viewport\" content=\"width=device-width\"><style nonce=\"\(nonce)\">\(baseCSS)\n\(Self.styles(preferences))</style></head><body><main>\(content)</main></body></html>"
        return PreviewSnapshot(version: version, html: html, token: token, resources: Array(Dictionary(images.values.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values), links: links, fragments: fragments, visibleText: visible.projection, imageResources: images)
    }

    static func escape(_ value: String) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(value.utf8.count + 32)
        for byte in value.utf8 {
            switch byte {
            case 38: bytes.append(contentsOf: [38, 97, 109, 112, 59])
            case 60: bytes.append(contentsOf: [38, 108, 116, 59])
            case 62: bytes.append(contentsOf: [38, 103, 116, 59])
            case 34: bytes.append(contentsOf: [38, 113, 117, 111, 116, 59])
            case 39: bytes.append(contentsOf: [38, 35, 51, 57, 59])
            default: bytes.append(byte)
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    static func link(_ raw: String, relativeTo documentURL: URL) -> PreviewLink {
        guard !raw.isEmpty, !raw.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              !raw.contains("\\") else { return .refused }
        if raw.hasPrefix("#") {
            guard let fragment = String(raw.dropFirst()).removingPercentEncoding else { return .refused }
            return .fragment(fragment)
        }
        guard let components = URLComponents(string: raw) else { return .refused }
        if let scheme = components.scheme {
            guard ["http", "https"].contains(scheme.lowercased()), components.user == nil, components.password == nil,
                  let host = components.host, !host.isEmpty, let url = components.url else { return .refused }
            return .web(url)
        }
        let lower = raw.lowercased()
        guard !raw.hasPrefix("//"), !lower.contains("%25"), !lower.contains("%2f"), !lower.contains("%5c"),
              let url = URL(string: raw, relativeTo: documentURL)?.absoluteURL, url.isFileURL else { return .refused }
        return .local(url)
    }

    private static func styles(_ prefs: RenderPreferences) -> String {
        func color(_ c: SRGBColor) -> String { "rgb(\(Int((c.red * 255).rounded())),\(Int((c.green * 255).rounded())),\(Int((c.blue * 255).rounded())))" }
        func palette(_ p: ReadingPalette) -> String { "--reader-text:\(color(p.text));--reader-bg:\(color(p.background));--reader-link:\(color(p.link));" }
        let light = palette(prefs.lightPalette), dark = palette(prefs.darkPalette)
        let font = prefs.fontIdentifier.map { "\"" + $0.unicodeScalars.map { "\\" + String($0.value, radix: 16) + " " }.joined() + "\",system-ui" } ?? "system-ui"
        let lineHeight = prefs.style == .compact ? "1.35" : prefs.style == .airy ? "1.9" : "1.6"
        let colors: String
        switch prefs.theme {
        case .light: colors = ":root{\(light)color-scheme:light;}"
        case .dark: colors = ":root{\(dark)color-scheme:dark;}"
        case .system: colors = ":root{\(light)color-scheme:light dark;}@media(prefers-color-scheme:dark){:root{\(dark)}}"
        }
        return colors + "body{font-family:\(font);font-size:\(prefs.fontSize)pt;line-height:\(lineHeight);}"
    }
}
