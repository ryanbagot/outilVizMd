import Foundation

struct DeploymentRequest {
    var operation: String
    var source: URL?
    var replace = false
    var dryRun = false
    var json = false
}

struct DeploymentResult: Codable {
    var schemaVersion = 1
    var operation: String
    var outcome = "failed"
    var applicationState = "absent"
    var aliasState = "nonVérifié"
    var applicationPath: String
    var aliasPath: String?
    var bundleIdentifier: String?
    var version: String?
    var build: String?
    var changed = false
    var diagnostics: [String] = []
    var recoveryPaths: [String] = []
    var plannedActions: [String]?
    var processes: [String] = []
}

struct DeploymentError: Error, CustomStringConvertible {
    let code: Int32
    let description: String
    init(_ code: Int32, _ message: String) { self.code = code; description = message }
}

@main struct Command {
    static let help = """
    outilVizMd — installation locale (sans élévation automatique)
    install --source PATH [--replace] [--dry-run] [--json]
    alias [--dry-run] [--json]
    status [--json]
    Destination : /Applications/outilVizMd.app ; alias outilVizMd – ouvrir au Bureau fourni par macOS.
    --replace autorise uniquement le remplacement de l’application identifiée.
    --dry-run ne modifie rien. status inspecte sans lancer l’app.
    En cas de conflit, inspecter puis déplacer soi-même l’objet ; aucun écrasement forcé.
    Un résultat partiel (code 1) conserve une app utilisable ; réparer avec alias.
    """
    static func parse(_ args: [String]) throws -> DeploymentRequest {
        guard let operation = args.first, ["install", "alias", "status"].contains(operation) else { throw DeploymentError(64, help) }
        var request = DeploymentRequest(operation: operation)
        var index = 1; var seen = Set<String>()
        while index < args.count {
            let option = args[index]
            guard seen.insert(option).inserted else { throw DeploymentError(64, "Option répétée : \(option)") }
            switch option {
            case "--json": request.json = true
            case "--replace" where operation == "install": request.replace = true
            case "--dry-run" where operation != "status": request.dryRun = true
            case "--source" where operation == "install":
                index += 1
                guard index < args.count, !args[index].hasPrefix("--") else { throw DeploymentError(64, "Chemin source requis.") }
                request.source = URL(fileURLWithPath: args[index]).standardizedFileURL
            default: throw DeploymentError(64, "Option invalide : \(option)\n\(help)")
            }
            index += 1
        }
        if operation == "install", request.source == nil { throw DeploymentError(64, "install exige --source PATH.") }
        return request
    }
    static func json(_ result: DeploymentResult) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(result)
    }
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if args == ["--help"] || args == ["-h"] { print(help); return }
        do {
            let request = try parse(args)
            let (result, code) = Deployment(environment: .production).execute(request)
            if request.json { FileHandle.standardOutput.write(try json(result)); print("") }
            else {
                print("Application : \(result.applicationPath) — \(result.applicationState), version \(result.version ?? "inconnue")")
                print("Raccourci : \(result.aliasPath ?? "Bureau indisponible") — \(result.aliasState)")
                let outcomes = ["complete": "réussite complète", "partial": "réussite partielle", "failed": "échec", "refused": "refus", "preview": "simulation", "status": "inspection"]
                print("Résultat : \(outcomes[result.outcome] ?? result.outcome) ; changement : \(result.changed ? "oui" : "non")")
                for line in result.plannedActions ?? [] { print("Prévu : \(line)") }
                for line in result.diagnostics { print(line) }
                for path in result.recoveryPaths { print("Récupération : \(path)") }
            }
            exit(code)
        } catch {
            let diagnostic = error as? DeploymentError ?? DeploymentError(6, String(describing: error))
            FileHandle.standardError.write(Data((diagnostic.description + "\n").utf8))
            exit(diagnostic.code)
        }
    }
}
