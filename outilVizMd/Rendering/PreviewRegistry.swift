import Foundation

@MainActor
final class PreviewRegistry {
    private var controllers: [UUID: PreviewController] = [:]
    func get(_ id: UUID) -> PreviewController? { controllers[id] }
    func set(_ controller: PreviewController, for id: UUID) {
        if let old = controllers[id], old !== controller { old.close() }
        controllers[id] = controller
    }
    func remove(_ id: UUID) { controllers.removeValue(forKey: id)?.close() }
}
