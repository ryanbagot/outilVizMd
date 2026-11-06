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

    var resourceIDs: [UUID] { resources.map(\.id) }
}
