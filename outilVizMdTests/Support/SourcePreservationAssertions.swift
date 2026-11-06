import CryptoKit
import Foundation
import XCTest

struct ReferenceSource {
    let url: URL
    let bytes: Data
    let digest: Data

    init(_ url: URL) throws {
        self.url = url.standardizedFileURL
        bytes = try Data(contentsOf: url)
        digest = Data(SHA256.hash(data: bytes))
    }
}

func assertSourcePreserved(_ reference: ReferenceSource, at currentURL: URL,
                           file: StaticString = #filePath, line: UInt = #line) throws {
    XCTAssertEqual(currentURL.standardizedFileURL, reference.url, "Le document a changé d’emplacement", file: file, line: line)
    let bytes = try Data(contentsOf: reference.url)
    XCTAssertTrue(bytes == reference.bytes, "Les octets du document ont changé", file: file, line: line)
    XCTAssertTrue(Data(SHA256.hash(data: bytes)) == reference.digest, "L’empreinte du document a changé", file: file, line: line)
}
