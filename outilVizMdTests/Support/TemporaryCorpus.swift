import Foundation

/// Chaque test possède un répertoire distinct et le supprime dans son teardown.
final class TemporaryCorpus {
    enum Failure: Error { case missingFixtures, invalidRelativePath }

    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("outilVizMd-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func copyFixtures() throws {
        guard let fixtures = Bundle(for: TemporaryCorpus.self).resourceURL?
            .appendingPathComponent("Fixtures", isDirectory: true),
              FileManager.default.fileExists(atPath: fixtures.path) else {
            throw Failure.missingFixtures
        }
        for item in try FileManager.default.contentsOfDirectory(at: fixtures, includingPropertiesForKeys: nil) {
            try FileManager.default.copyItem(at: item, to: root.appendingPathComponent(item.lastPathComponent))
        }
    }

    func url(_ relativePath: String) throws -> URL {
        let parts = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.hasPrefix("/"), !parts.isEmpty,
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw Failure.invalidRelativePath
        }
        return root.appendingPathComponent(relativePath)
    }

    @discardableResult
    func write(_ data: Data, to relativePath: String, atomic: Bool = false) throws -> URL {
        let destination = try url(relativePath)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: atomic ? .atomic : [])
        return destination
    }

    func remove() throws {
        try FileManager.default.removeItem(at: root)
    }
}
