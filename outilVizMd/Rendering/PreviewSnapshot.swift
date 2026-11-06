import Foundation

struct PresentationVersion: Hashable, Sendable {
    let documentID: UUID
    let sourceGeneration: UInt64
    let presentationGeneration: UInt64
}

struct ResourceSnapshot: Identifiable, Sendable {
    enum MIME: String, Sendable {
        case html = "text/html"
        case css = "text/css"
        case png = "image/png"
        case jpeg = "image/jpeg"
    }

    let id: UUID
    let previewToken: UUID
    let bytes: Data
    let mime: MIME
    let pixelWidth: Int?
    let pixelHeight: Int?
    let alternativeText: String
}

struct PreviewSnapshot: Sendable {
    let version: PresentationVersion
    let html: String
    let token: UUID
    let resources: [ResourceSnapshot]
    let htmlData: Data
    let links: [UUID: PreviewLink]
    let fragments: Set<String>
    let visibleText: VisibleTextProjection?
    let imageResources: [Int: ResourceSnapshot]

    init(version: PresentationVersion, html: String, token: UUID, resources: [ResourceSnapshot], links: [UUID: PreviewLink] = [:], fragments: Set<String> = [], visibleText: VisibleTextProjection? = nil, imageResources: [Int: ResourceSnapshot] = [:]) {
        self.version = version
        self.html = html
        self.token = token
        self.resources = resources
        self.htmlData = Data(html.utf8)
        self.links = links
        self.fragments = fragments
        self.visibleText = visibleText
        self.imageResources = imageResources
    }

    var resourceIDs: [UUID] { resources.map(\.id) }
}

enum PreviewLink: Sendable {
    case web(URL), local(URL), fragment(String), refused
}
