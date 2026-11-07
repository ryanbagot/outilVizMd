import Foundation

struct AliasInspection {
    var state: String
    var url: URL?
    var target: URL?
    var targetIdentity: String?
}

struct DesktopAlias {
    static let name = "outilVizMd – ouvrir"
    let desktop: () throws -> URL
}

extension DesktopAlias {
    func location() throws -> URL {
        let folder = try desktop()
        // Un Bureau non inspectable n’est jamais assimilé à un raccourci absent.
        _ = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        return folder.appendingPathComponent(Self.name)
    }
    func inspect(application: URL) throws -> AliasInspection {
        let alias = try location()
        guard FileSystem.exists(alias) else { return AliasInspection(state: "absent", url: alias) }
        guard !FileSystem.isSymlink(alias),
              try alias.resourceValues(forKeys: [.isAliasFileKey]).isAliasFile == true,
              let target = try? URL(resolvingAliasFileAt: alias, options: [.withoutUI, .withoutMounting]) else {
            return AliasInspection(state: "conflit", url: alias)
        }
        return AliasInspection(state: FileSystem.same(target, application) ? "valide" : "conflit", url: alias,
            target: target, targetIdentity: try? FileSystem.identity(target))
    }
    func secure(application: URL, transaction: String) throws -> (URL, String)? {
        let inspection = try inspect(application: application)
        guard inspection.state == "valide", let alias = inspection.url else { return nil }
        let identity = try FileSystem.identity(alias)
        let backup = alias.deletingLastPathComponent().appendingPathComponent(".outilVizMd-alias-\(transaction)")
        try FileSystem.rename(alias, backup)
        guard try FileSystem.identity(backup) == identity else { throw DeploymentError(8, "Identité du raccourci modifiée ; inspecter \(backup.path).") }
        return (backup, identity)
    }
    func restore(backup: URL, identity: String) throws {
        guard try FileSystem.identity(backup) == identity else { throw DeploymentError(8, "Sauvegarde d’alias modifiée : \(backup.path)") }
        try FileSystem.rename(backup, location())
    }
    @discardableResult func publish(application: URL) throws -> Bool {
        let inspection = try inspect(application: application)
        if inspection.state == "valide" { return false }
        guard inspection.state == "absent", let destination = inspection.url else { throw DeploymentError(2, "Conflit au Bureau : déplacer soi-même l’objet après inspection ; aucun écrasement autorisé.") }
        let expected = try FileSystem.identity(application)
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".outilVizMd-\(UUID().uuidString).alias")
        let data = try application.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
        try URL.writeBookmarkData(data, to: temporary)
        let ownID = try FileSystem.identity(temporary)
        defer { if (try? FileSystem.identity(temporary)) == ownID { try? FileManager.default.removeItem(at: temporary) } }
        try FileSystem.rename(temporary, destination)
        do {
            let verified = try inspect(application: application)
            guard try FileSystem.identity(application) == expected, verified.state == "valide" else {
                throw DeploymentError(6, "Alias non conforme (\(verified.state)) : cible \(verified.target?.path ?? "non résolue"), identité \(verified.targetIdentity ?? "inconnue") ; attendu \(application.path), identité \(expected).")
            }
        } catch {
            if (try? FileSystem.identity(destination)) == ownID { try FileManager.default.removeItem(at: destination) }
            throw error
        }
        return true
    }
}
