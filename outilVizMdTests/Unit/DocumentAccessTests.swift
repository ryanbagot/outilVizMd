import XCTest
@testable import outilVizMd

final class DocumentAccessTests: XCTestCase {
    func testBoundedUTF8ReadPreservesBOMAndSourceBytes() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let data = Data([0xef, 0xbb, 0xbf]) + Data("# café\r\n".utf8)
        let url = try corpus.write(data, to: "document.md")
        let reference = try ReferenceSource(url)
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(url, kind: .file)
        let handle = try await access.handle(for: url, grantID: grant.id)
        let snapshot = try await LocalDocumentReader(access: access).read(handle: handle, generation: 1)
        XCTAssertEqual(snapshot.bytes, data)
        XCTAssertEqual(snapshot.text, "# café\r\n")
        try assertSourcePreserved(reference, at: url)
        _ = await access.release(grant.id)
    }

    func testFileGrantNeverAllowsItsNeighbourOrARevokedRead() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let url = try corpus.write(Data("texte".utf8), to: "a.md")
        let neighbour = try corpus.write(Data("secret".utf8), to: "b.md")
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(url, kind: .file)
        do { _ = try await access.read(neighbour, grantID: grant.id, maximumBytes: 100); XCTFail("Voisin autorisé implicitement") } catch { }
        _ = await access.release(grant.id)
        do { _ = try await access.read(url, grantID: grant.id, maximumBytes: 100); XCTFail("Grant révoqué accepté") } catch { }
    }

    func testLimitIsInclusiveAndRejectsGrowthPastTheLimit() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let url = try corpus.write(Data(repeating: 65, count: DocumentSnapshot.maximumByteCount), to: "limit.md")
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(corpus.root, kind: .directory)
        let reader = LocalDocumentReader(access: access)
        let handle = try await access.handle(for: url, grantID: grant.id)
        let valid = try await reader.read(handle: handle, generation: 1)
        XCTAssertEqual(valid.bytes.count, DocumentSnapshot.maximumByteCount)
        try Data(repeating: 65, count: DocumentSnapshot.maximumByteCount + 1).write(to: url)
        do { _ = try await reader.read(handle: handle, generation: 2); XCTFail("Limite dépassée acceptée") }
        catch let failure as ReaderFailure { XCTAssertEqual(failure.category, .sizeExceeded) }
    }

    func testInvalidUTF8AndNULAreRefusedButEmptyIsAccepted() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(corpus.root, kind: .directory)
        for data in [Data([0xff, 0xc0]), Data([65, 0, 66])] {
            let url = try corpus.write(data, to: "invalid.md")
            let handle = try await access.handle(for: url, grantID: grant.id)
            do { _ = try await LocalDocumentReader(access: access).read(handle: handle, generation: 1); XCTFail("Contenu incompatible accepté") } catch { }
        }
        let empty = try corpus.write(Data(), to: "empty.md")
        let handle = try await access.handle(for: empty, grantID: grant.id)
        let snapshot = try await LocalDocumentReader(access: access).read(handle: handle, generation: 1)
        XCTAssertEqual(snapshot.text, "")
    }

    func testDescendantSymlinksAndCommonTextualPrefixesAreRefused() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let root = corpus.root.appendingPathComponent("allowed", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let outside = try corpus.write(Data("secret".utf8), to: "allowed-other/secret.md")
        let link = root.appendingPathComponent("link.md")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(root, kind: .directory)
        for url in [link, outside] {
            do { _ = try await access.read(url, grantID: grant.id, maximumBytes: 100); XCTFail("Lecture hors périmètre") } catch { }
        }
    }
}
