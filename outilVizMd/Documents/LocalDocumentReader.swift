import Foundation

actor LocalDocumentReader {
    let access: AuthorizedFileAccess
    init(access: AuthorizedFileAccess) { self.access = access }

    func read(handle: DocumentHandle, generation: UInt64) async throws -> DocumentSnapshot {
        for attempt in 0..<3 {
            do {
                // L’acteur d’accès coordonne la lecture effective et vérifie les descripteurs.
                let result = try await access.read(handle.location, grantID: handle.grantID, maximumBytes: DocumentSnapshot.maximumByteCount)
                guard !result.bytes.contains(0) else { throw AuthorizedFileAccess.unsupported }
                return try DocumentSnapshot(documentID: handle.id, generation: generation, bytes: result.bytes, metadataBefore: result.before, metadataAfter: result.after)
            } catch let failure as ReaderFailure where failure.category == .unstableRead && attempt < 2 {
                try await Task.sleep(for: .milliseconds(50))
            }
        }
        throw ReaderFailure.unstableRead(handle.id)
    }

}
