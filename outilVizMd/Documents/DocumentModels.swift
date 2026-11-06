import CryptoKit
import Foundation

struct AccessGrant: Identifiable, Sendable {
    enum Kind: Sendable { case file, directory }
    enum State: Sendable { case active, revoked }

    let id: UUID
    let selectedURL: URL
    let kind: Kind
    let resolvedRoot: URL
    var state: State
    var usageCount: Int

    init(id: UUID = UUID(), selectedURL: URL, kind: Kind, resolvedRoot: URL) {
        self.id = id
        self.selectedURL = selectedURL
        self.kind = kind
        self.resolvedRoot = resolvedRoot
        state = .active
        usageCount = 0
    }
}

struct FileIdentity: Hashable, Sendable {
    let device: UInt64
    let inode: UInt64
}

struct FileMetadata: Equatable, Sendable {
    let identity: FileIdentity
    let byteCount: UInt64
    let modificationTime: Date
    let changeTime: Date
}

struct DocumentHandle: Identifiable, Sendable {
    let id: UUID
    let location: URL
    let identity: FileIdentity
    let grantID: UUID

    var displayName: String { location.lastPathComponent }
    var displayPath: String { location.path }

    init(id: UUID = UUID(), location: URL, identity: FileIdentity, grantID: UUID) {
        self.id = id
        self.location = location
        self.identity = identity
        self.grantID = grantID
    }
}

/// Valeur produite après une lecture bornée et stable. Aucun accès disque ni sauvegarde ici.
struct DocumentSnapshot: Sendable {
    static let maximumByteCount = 10 * 1_024 * 1_024

    let documentID: UUID
    let generation: UInt64
    let bytes: Data
    let text: String
    let digest: Data
    let metadataBefore: FileMetadata
    let metadataAfter: FileMetadata

    init(documentID: UUID, generation: UInt64, bytes: Data,
         metadataBefore: FileMetadata, metadataAfter: FileMetadata) throws {
        guard bytes.count <= Self.maximumByteCount else {
            throw ReaderFailure.documentTooLarge(documentID)
        }
        guard metadataBefore == metadataAfter,
              metadataAfter.byteCount == UInt64(bytes.count) else {
            throw ReaderFailure.unstableRead(documentID)
        }
        guard var text = String(data: bytes, encoding: .utf8) else {
            throw ReaderFailure.invalidUTF8(documentID)
        }
        if text.first == "\u{FEFF}" { text.removeFirst() }
        self.documentID = documentID
        self.generation = generation
        self.bytes = bytes
        self.text = text
        digest = Data(SHA256.hash(data: bytes))
        self.metadataBefore = metadataBefore
        self.metadataAfter = metadataAfter
    }
}
