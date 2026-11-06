import Foundation

/// L’annulation du consommateur n’achève volontairement pas le travail : on peut livrer
/// ensuite une réponse tardive et vérifier qu’elle ne rétablit jamais une présentation périmée.
actor ControlledAsyncWork<Value: Sendable> {
    enum Failure: Error { case duplicateRequest, unknownRequest, cancelled }
    private var continuations: [UUID: CheckedContinuation<Value, Error>] = [:]

    func run(id: UUID) async throws -> Value {
        guard continuations[id] == nil else { throw Failure.duplicateRequest }
        return try await withCheckedThrowingContinuation { continuations[id] = $0 }
    }

    func isWaiting(_ id: UUID) -> Bool { continuations[id] != nil }

    func resolve(_ id: UUID, with result: Result<Value, Error>) throws {
        guard let continuation = continuations.removeValue(forKey: id) else { throw Failure.unknownRequest }
        continuation.resume(with: result)
    }

    func cancelAll() {
        let waiting = continuations.values
        continuations.removeAll()
        for continuation in waiting { continuation.resume(throwing: Failure.cancelled) }
    }
}
