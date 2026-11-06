import Foundation

enum PreviewNavigation: Equatable {
    case allowDocument, fragment(String), openExternal(URL), openLocal(URL), refuse
}

enum NavigationPolicy {
    static func decide(_ url: URL, explicitClick: Bool, preview: PreviewSnapshot) -> PreviewNavigation {
        guard let parts = PreviewResourceStore.parts(url), UUID(uuidString: parts[0]) == preview.token else { return .refuse }
        if parts.count == 2, parts[1] == "document" {
            guard let fragment = url.fragment, !fragment.isEmpty else { return .allowDocument }
            return preview.fragments.contains(fragment) ? .allowDocument : .refuse
        }
        guard explicitClick, parts.count == 3, parts[1] == "link", let id = UUID(uuidString: parts[2]), let target = preview.links[id] else { return .refuse }
        switch target {
        case let .fragment(fragment): return preview.fragments.contains(fragment) ? .fragment(fragment) : .refuse
        case let .web(url):
            guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil, url.user == nil, url.password == nil else { return .refuse }
            return .openExternal(url)
        case let .local(url): return url.isFileURL ? .openLocal(url) : .refuse
        case .refused: return .refuse
        }
    }
}
