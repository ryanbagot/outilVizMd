import Foundation
import ImageIO
import UniformTypeIdentifiers

actor LocalImageLoader {
    let access: AuthorizedFileAccess
    init(access: AuthorizedFileAccess) { self.access = access }

    func load(_ url: URL, grantID: UUID, token: UUID, alternativeText: String) async throws -> ResourceSnapshot {
        let read = try await access.read(url, grantID: grantID, maximumBytes: 16 * 1_024 * 1_024)
        let bytes = read.bytes
        let png = bytes.starts(with: [137, 80, 78, 71, 13, 10, 26, 10])
        let jpeg = bytes.starts(with: [255, 216, 255])
        let gif = bytes.starts(with: Data("GIF87a".utf8)) || bytes.starts(with: Data("GIF89a".utf8))
        guard png || jpeg || gif,
              let source = CGImageSourceCreateWithData(bytes as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0, width <= 16_384, height <= 16_384,
              width <= 16_777_216 / height,
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else {
            throw Self.unavailable
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { throw Self.unavailable }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination), output.length <= 32 * 1_024 * 1_024 else { throw Self.unavailable }
        return ResourceSnapshot(id: UUID(), previewToken: token, bytes: output as Data, mime: .png, pixelWidth: width, pixelHeight: height, alternativeText: alternativeText)
    }

    static let unavailable = ReaderFailure(category: .resourceUnavailable, message: "Cette image n’est pas disponible ou dépasse le budget de décodage.", recoveries: [.selectFolder, .retry], documentID: nil)
}
