import Foundation
import AppKit
import Darwin

struct PreparedRelease: Codable, Equatable {
    var schemaVersion = 1
    var bundleIdentifier: String
    var version: String
    var build: String
    var architectures: [String]
    var minimumOS: String
    var sourceSHA256: String
    var iconSHA256: String
    var bundleDigest: String
}

struct Transaction: Codable {
    var id: String
    var stage: String
    var step: String
    var originalIdentity: String?
    var newIdentity: String?
    var aliasBackup: String?
    var aliasIdentity: String?
}

struct DeploymentEnvironment {
    var application: URL
    var desktop: () throws -> URL
    var validate: (URL) throws -> PreparedRelease
    var activeProcesses: () throws -> [String]
    var fault: (String) throws -> Void = { _ in }
}

extension DeploymentEnvironment {
    static var production: DeploymentEnvironment {
        let canonical = URL(fileURLWithPath: "/Applications/outilVizMd.app")
        return DeploymentEnvironment(application: canonical, desktop: {
            guard let url = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
                throw DeploymentError(5, "Bureau indisponible ; rétablir son accès puis lancer alias.")
            }
            return url
        }, validate: BundleValidator.validate, activeProcesses: {
            var matches: [String] = []
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: BundleValidator.identifier) {
                guard let url = app.bundleURL else { matches.append("PID \(app.processIdentifier), identité ambiguë"); continue }
                if url.resolvingSymlinksInPath().standardizedFileURL == canonical {
                    matches.append("PID \(app.processIdentifier) : \(url.path)")
                }
            }
            return matches
        })
    }
}

final class Deployment {
    let environment: DeploymentEnvironment
    let aliases: DesktopAlias
    let files = FileManager.default
    var application: URL { environment.application }
    var parent: URL { application.deletingLastPathComponent() }
    init(environment: DeploymentEnvironment) {
        self.environment = environment; aliases = DesktopAlias(desktop: environment.desktop)
    }
    func residuals() throws -> [URL] {
        try files.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix(".outilVizMd-install-") }.sorted { $0.path < $1.path }
    }
    func inspection(_ request: DeploymentRequest) throws -> DeploymentResult {
        var result = DeploymentResult(operation: request.operation, applicationPath: application.path)
        _ = try files.contentsOfDirectory(atPath: parent.path)
        if FileSystem.exists(application) {
            if let valid = try? environment.validate(application) {
                result.applicationState = "valide"; result.bundleIdentifier = valid.bundleIdentifier
                result.version = valid.version; result.build = valid.build
            } else {
                let identifier = NSDictionary(contentsOf: application.appendingPathComponent("Contents/Info.plist"))?["CFBundleIdentifier"] as? String
                result.applicationState = identifier == BundleValidator.identifier && !FileSystem.isSymlink(application) ? "invalide" : "conflit"
            }
        }
        do {
            let alias = try aliases.inspect(application: application); result.aliasPath = alias.url?.path; result.aliasState = alias.state
        } catch { result.aliasState = "inaccessible"; result.diagnostics.append("Bureau inaccessible : \(error). Rétablir son accès puis lancer alias.") }
        result.processes = try environment.activeProcesses()
        result.recoveryPaths = try residuals().map(\.path)
        if !result.recoveryPaths.isEmpty { result.diagnostics.append("Transaction résiduelle : inspecter receipt.json et les chemins conservés ; aucune reprise automatique.") }
        return result
    }
    func lock() throws -> Int32 {
        let path = parent.appendingPathComponent(".outilVizMd-deployment.lock").path
        let fd = open(path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw FileSystem.posix("Verrou \(path)") }
        var value = stat()
        guard fstat(fd, &value) == 0, value.st_uid == getuid(), value.st_mode & S_IFMT == S_IFREG else {
            close(fd); throw DeploymentError(2, "Verrou étranger : \(path)")
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { close(fd); throw DeploymentError(7, "Une autre opération est en cours ; réessayer après sa fin.") }
        // Le fichier de verrou n’est pas retiré : tous les concurrents gardent le même inode.
        return fd
    }
    func execute(_ request: DeploymentRequest) -> (DeploymentResult, Int32) {
        var result = DeploymentResult(operation: request.operation, applicationPath: application.path)
        do {
            result = try inspection(request)
            if request.operation == "status" { result.outcome = "status"; return (result, result.aliasState == "inaccessible" ? 5 : 0) }
            guard result.recoveryPaths.isEmpty else { throw DeploymentError(8, "Récupération nécessaire ; inspecter les reçus avant toute mutation.") }
            let sourceRelease = try preflight(request, result: result)
            if request.dryRun {
                result.outcome = "preview"; result.plannedActions = request.operation == "alias" ? ["Vérifier/créer l’alias reconnu"] : ["Installer si absent ou remplacer si autorisé", "Vérifier/créer l’alias reconnu"]
                return (result, 0)
            }
            let fd = try lock(); defer { flock(fd, LOCK_UN); close(fd) }
            result = try inspection(request)
            guard result.recoveryPaths.isEmpty else { throw DeploymentError(8, "Transaction interrompue à inspecter.") }
            _ = try preflight(request, result: result)
            if request.operation == "alias" {
                let changed = try aliases.publish(application: application)
                result = try inspection(request); result.changed = changed; result.outcome = "complete"
                return (result, 0)
            }
            guard let source = request.source, let prepared = sourceRelease else { throw DeploymentError(4, "Source préparée requise.") }
            if result.applicationState == "valide", try environment.validate(application).bundleDigest == prepared.bundleDigest {
                do {
                    let changed = try aliases.publish(application: application)
                    result = try inspection(request); result.changed = changed; result.outcome = "complete"
                    return (result, 0)
                } catch {
                    result = try inspection(request); result.outcome = "partial"; result.diagnostics.append("Application identique conservée. \(error)")
                    return (result, 1)
                }
            }
            return try transact(source: source, prepared: prepared, request: request)
        } catch {
            let diagnostic = error as? DeploymentError ?? DeploymentError(5, "Accès impossible : \(error). Vérifier les droits/espace puis réessayer.")
            if let actual = try? inspection(request) { result = actual }
            result.outcome = [2,3,7,8].contains(diagnostic.code) ? "refused" : "failed"
            result.diagnostics.append(diagnostic.description)
            return (result, diagnostic.code)
        }
    }
    func preflight(_ request: DeploymentRequest, result: DeploymentResult) throws -> PreparedRelease? {
        if request.operation == "alias" {
            guard result.applicationState == "valide" else { throw DeploymentError(4, "Installer une application valide avant de réparer l’alias.") }
            if result.aliasState == "conflit" { throw DeploymentError(2, "Conflit au Bureau ; déplacer l’objet après inspection.") }
            if result.aliasState == "inaccessible" { throw DeploymentError(5, "Bureau inaccessible ; rétablir son accès.") }
            return nil
        }
        guard let source = request.source else { throw DeploymentError(4, "Source absente.") }
        let release: PreparedRelease
        do {
            release = try environment.validate(source)
            let manifestURL = source.deletingLastPathComponent().appendingPathComponent("manifest.json")
            guard !FileSystem.isSymlink(manifestURL) else { throw DeploymentError(4, "Manifeste réel requis.") }
            let manifest = try JSONDecoder().decode(PreparedRelease.self, from: Data(contentsOf: manifestURL))
            guard manifest.schemaVersion == 1, manifest == release else { throw DeploymentError(4, "Manifeste différent du bundle réel ; refaire la préparation.") }
        } catch { throw DeploymentError(4, "Source/manifeste invalide : \(error)") }
        if ["conflit", "invalide"].contains(result.applicationState) { throw DeploymentError(2, "Destination occupée ou invalide ; inspecter \(application.path), aucun remplacement effectué.") }
        if result.applicationState == "valide" {
            let old = try environment.validate(application)
            if old.bundleDigest == release.bundleDigest { return release }
            guard request.replace else { throw DeploymentError(2, "Version différente : utiliser --replace pour demander explicitement le remplacement.") }
            guard result.processes.isEmpty else { throw DeploymentError(3, "Quitter normalement l’app avant mise à jour : \(result.processes.joined(separator: ", "))") }
            if result.aliasState == "inaccessible" { throw DeploymentError(5, "Impossible de sécuriser l’ancien alias ; rétablir l’accès au Bureau avant mise à jour.") }
        }
        guard access(parent.path, W_OK) == 0 else { throw DeploymentError(5, "Applications non accessible en écriture ; faire corriger les droits par son propriétaire.") }
        let attributes = try files.attributesOfFileSystem(forPath: parent.path)
        let free = (attributes[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
        let size = try sourceSize(source)
        guard free > size + 1_048_576 else { throw DeploymentError(5, "Espace insuffisant ; libérer de l’espace avant installation.") }
        return release
    }
    func sourceSize(_ source: URL) throws -> UInt64 {
        guard let e = files.enumerator(at: source, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { throw DeploymentError(4, "Source illisible.") }
        var sum: UInt64 = 0
        for case let url as URL in e {
            let v = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if v.isRegularFile == true { sum += UInt64(v.fileSize ?? 0) }
        }
        return sum
    }
    func transact(source: URL, prepared: PreparedRelease, request: DeploymentRequest) throws -> (DeploymentResult, Int32) {
        let id = UUID().uuidString
        let stage = parent.appendingPathComponent(".outilVizMd-install-\(id)")
        try files.createDirectory(at: stage, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let stageID = try FileSystem.identity(stage)
        let stagedApp = stage.appendingPathComponent("outilVizMd.app")
        let receiptURL = stage.appendingPathComponent("receipt.json")
        var receipt = Transaction(id: id, stage: stage.path, step: "created", originalIdentity: FileSystem.exists(application) ? try FileSystem.identity(application) : nil)
        let oldRelease = receipt.originalIdentity != nil ? try environment.validate(application) : nil
        var committed = false
        var appValidated = false
        func save(_ step: String) throws {
            receipt.step = step
            try JSONEncoder().encode(receipt).write(to: receiptURL, options: .atomic)
        }
        func cleanup() throws {
            try environment.fault("cleanup")
            guard try FileSystem.identity(stage) == stageID else { throw DeploymentError(8, "Staging modifié : \(stage.path)") }
            if FileSystem.exists(stagedApp) {
                let expected = committed ? receipt.originalIdentity : receipt.newIdentity
                if let expected, try FileSystem.identity(stagedApp) != expected { throw DeploymentError(8, "Objet de sauvegarde modifié : \(stagedApp.path)") }
                let expectedRelease = committed ? oldRelease : prepared
                if let expectedRelease, try environment.validate(stagedApp) != expectedRelease { throw DeploymentError(8, "Contenu de sauvegarde modifié : \(stagedApp.path)") }
            }
            if let backup = receipt.aliasBackup, let identity = receipt.aliasIdentity {
                let url = URL(fileURLWithPath: backup)
                if FileSystem.exists(url) {
                    guard try FileSystem.identity(url) == identity else { throw DeploymentError(8, "Sauvegarde d’alias modifiée : \(backup)") }
                    try files.removeItem(at: url)
                }
            }
            let allowed = Set(["receipt.json", "outilVizMd.app"])
            guard Set(try files.contentsOfDirectory(atPath: stage.path)).isSubset(of: allowed) else { throw DeploymentError(8, "Objet inconnu dans \(stage.path)") }
            try files.removeItem(at: stage)
        }
        do {
            try save("copyPlanned")
            try environment.fault("copy")
            try files.copyItem(at: source, to: stagedApp)
            receipt.newIdentity = try FileSystem.identity(stagedApp)
            guard try environment.validate(stagedApp) == prepared else { throw DeploymentError(6, "Copie non conforme.") }
            try save("copyValidated")
            if receipt.originalIdentity != nil {
                try environment.fault("secureAlias")
                // Écrire le chemin prévu avant le déplacement permet une récupération après interruption.
                let alias = try aliases.inspect(application: application)
                if alias.state == "valide", let url = alias.url {
                    receipt.aliasBackup = url.deletingLastPathComponent().appendingPathComponent(".outilVizMd-alias-\(id)").path
                    receipt.aliasIdentity = try FileSystem.identity(url)
                    try save("aliasSecurePlanned")
                    _ = try aliases.secure(application: application, transaction: id)
                }
            }
            try save("commitPlanned")
            try environment.fault("commit")
            let currentID = FileSystem.exists(application) ? try FileSystem.identity(application) : nil
            guard currentID == receipt.originalIdentity else { throw DeploymentError(2, "Destination modifiée pendant la transaction ; objet concurrent préservé.") }
            if let oldRelease {
                guard try environment.validate(application) == oldRelease else { throw DeploymentError(2, "Contenu installé modifié pendant la transaction.") }
                guard try environment.activeProcesses().isEmpty else { throw DeploymentError(3, "L’app vient de démarrer ; la quitter normalement avant mise à jour.") }
            }
            try FileSystem.rename(stagedApp, application, swap: receipt.originalIdentity != nil)
            committed = true
            try save("committed")
            try environment.fault("postCommit")
            guard try FileSystem.identity(application) == receipt.newIdentity, try environment.validate(application) == prepared else { throw DeploymentError(6, "Validation canonique échouée.") }
            appValidated = true
            try save("applicationValidated")
            var aliasError: Error?
            do { try environment.fault("alias"); _ = try aliases.publish(application: application) }
            catch { aliasError = error }
            try save("aliasAttempted")
            var cleanupError: Error?
            do { try cleanup() } catch { cleanupError = error }
            var result = try inspection(request); result.changed = true
            if let aliasError { result.diagnostics.append("App installée ; réparer l’alias avec la commande alias. \(aliasError)") }
            if let cleanupError { result.diagnostics.append("Nettoyage incomplet : \(cleanupError)") }
            let partial = aliasError != nil || cleanupError != nil
            result.outcome = partial ? "partial" : "complete"
            return (result, partial ? 1 : 0)
        } catch {
            let originalError = error
            // Après validation de l’app, un défaut de journal/alias ne doit pas masquer l’installation effective.
            if appValidated {
                var result = try inspection(request); result.changed = true; result.outcome = "partial"
                result.diagnostics.append("Application valide ; récupération à inspecter : \(originalError)")
                return (result, 1)
            }
            do {
                if committed {
                    try environment.fault("rollback")
                    guard try FileSystem.identity(application) == receipt.newIdentity else { throw DeploymentError(8, "Destination concurrente ; retour arrière automatique interdit.") }
                    if let original = receipt.originalIdentity {
                        guard try FileSystem.identity(stagedApp) == original else { throw DeploymentError(8, "Ancienne app modifiée ; récupération manuelle nécessaire.") }
                        try FileSystem.rename(stagedApp, application, swap: true)
                    } else { try FileSystem.rename(application, stagedApp) }
                    committed = false
                }
                if let backup = receipt.aliasBackup, let identity = receipt.aliasIdentity, FileSystem.exists(URL(fileURLWithPath: backup)) {
                    try aliases.restore(backup: URL(fileURLWithPath: backup), identity: identity)
                }
                try save("rolledBack")
                try cleanup()
            } catch {
                var result = try inspection(request); result.outcome = "failed"
                result.diagnostics.append("Échec : \(originalError). Récupération nécessaire : \(error). Inspecter \(receiptURL.path).")
                return (result, 8)
            }
            var result = try inspection(request); result.outcome = "failed"
            result.diagnostics.append("Installation échouée, ancien état conservé/restauré : \(originalError)")
            return (result, (originalError as? DeploymentError)?.code ?? 6)
        }
    }
}
