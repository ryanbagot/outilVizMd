import Darwin
import XCTest
@testable import outilVizMd

final class AccessRaceTests: XCTestCase {
    func testRepeatedSymlinkSubstitutionsNeverExposeOutsideBytes() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let file = try corpus.write(Data("allowed".utf8), to: "root/file.md")
        let outside = try corpus.write(Data("secret-outside".utf8), to: "outside.md")
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(file.deletingLastPathComponent(), kind: .directory)
        for _ in 0..<50 {
            try FileManager.default.removeItem(at: file)
            try FileManager.default.createSymbolicLink(at: file, withDestinationURL: outside)
            do { _ = try await access.read(file, grantID: grant.id, maximumBytes: 100); XCTFail("Un symlink descendant a été lu") } catch { }
            try FileManager.default.removeItem(at: file)
            try Data("allowed".utf8).write(to: file)
            let value = try await access.read(file, grantID: grant.id, maximumBytes: 100)
            XCTAssertEqual(value.bytes, Data("allowed".utf8))
        }
    }

    func testSpecialFileIsRefusedWithoutBlockingAndRevokedGrantFails() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let fifo = corpus.root.appendingPathComponent("pipe.md")
        XCTAssertEqual(mkfifo(fifo.path, S_IRUSR | S_IWUSR), 0)
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(corpus.root, kind: .directory)
        do { _ = try await access.read(fifo, grantID: grant.id, maximumBytes: 100); XCTFail("FIFO accepté") } catch { }
        _ = await access.release(grant.id)
        do { _ = try await access.listDirectory(corpus.root, grantID: grant.id); XCTFail("Grant fermé accepté") } catch { }
    }
    func testConcurrentAtomicSymlinkReplacementOnlyReturnsAuthorizedBytes() async throws {
        let corpus = try TemporaryCorpus()
        defer { try? corpus.remove() }
        let file = try corpus.write(Data(repeating: 65, count: 128 * 1024), to: "root/file.md")
        let outside = try corpus.write(Data("secret-outside".utf8), to: "outside.md")
        let access = AuthorizedFileAccess()
        let grant = try await access.authorizeSelectedURL(file.deletingLastPathComponent(), kind: .directory)
        let writer = Task.detached {
            for index in 0..<200 {
                let temporary = file.deletingLastPathComponent().appendingPathComponent("swap-\(index)")
                if index.isMultiple(of: 2) {
                    try FileManager.default.createSymbolicLink(at: temporary, withDestinationURL: outside)
                } else { try Data(repeating: 65, count: 128 * 1024).write(to: temporary) }
                guard rename(temporary.path, file.path) == 0 else { throw CocoaError(.fileWriteUnknown) }
                try await Task.sleep(for: .microseconds(100))
            }
        }
        for _ in 0..<100 {
            do {
                let read = try await access.read(file, grantID: grant.id, maximumBytes: 128 * 1024)
                XCTAssertEqual(read.bytes, Data(repeating: 65, count: 128 * 1024))
            } catch { /* Une identité instable ou un symlink est un refus attendu. */ }
        }
        try await writer.value
        XCTAssertEqual(try Data(contentsOf: outside), Data("secret-outside".utf8))
    }

}
