import Foundation
import AppKit
import CryptoKit
import Darwin

// L’identité de fichier est distincte du digest : un alias peut suivre un ancien inode.
enum FileSystem {
    static func metadata(_ url: URL) throws -> stat {
        var value = stat()
        guard lstat(url.path, &value) == 0 else { throw posix("Inspecter \(url.path)") }
        return value
    }
    static func exists(_ url: URL) -> Bool { var s = stat(); return lstat(url.path, &s) == 0 }
    static func isSymlink(_ url: URL) -> Bool { (try? metadata(url).st_mode & S_IFMT) == S_IFLNK }
    static func identity(_ url: URL) throws -> String {
        let s = try metadata(url); return "\(s.st_dev):\(s.st_ino)"
    }
    static func posix(_ context: String) -> DeploymentError {
        let value = errno
        return DeploymentError([EACCES, EPERM, ENOSPC, EDQUOT, EROFS].contains(value) ? 5 : 6,
            "\(context) : \(String(cString: strerror(value))). Vérifier droits/espace et réessayer.")
    }
    static func rename(_ from: URL, _ to: URL, swap: Bool = false) throws {
        guard renameatx_np(AT_FDCWD, from.path, AT_FDCWD, to.path, swap ? UInt32(RENAME_SWAP) : UInt32(RENAME_EXCL)) == 0 else {
            throw posix("Déplacer \(from.path) vers \(to.path)")
        }
    }
    static func same(_ first: URL, _ second: URL) -> Bool {
        guard let a = try? identity(first), let b = try? identity(second) else { return false }
        return a == b && first.resolvingSymlinksInPath().standardizedFileURL.path == second.resolvingSymlinksInPath().standardizedFileURL.path
    }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}

enum SystemCommand {
    static func run(_ executable: String, _ arguments: [String], stderr: Bool = false) throws -> Data {
        // Fichiers temporaires : les sorties codesign ne peuvent pas saturer un pipe.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("outilvizmd-command-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let out = directory.appendingPathComponent("stdout"), err = directory.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: out.path, contents: nil)
        FileManager.default.createFile(atPath: err.path, contents: nil)
        let output = try FileHandle(forWritingTo: out), errors = try FileHandle(forWritingTo: err)
        defer { try? output.close(); try? errors.close() }
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        process.standardOutput = output; process.standardError = errors
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw DeploymentError(4, "Validation refusée par \(executable) : \(String(decoding: try Data(contentsOf: err), as: UTF8.self))")
        }
        return try Data(contentsOf: stderr ? err : out)
    }
}

enum BundleValidator {
    static let identifier = "com.outilvizmd.outilVizMd"
    static let sourceHash = "2f568a19b834a308bce6c9ec56194f6c1e4090a69e5d6381ac3a6c350ce05be7"
    static func digest(_ bundle: URL) throws -> String {
        let root = bundle.resolvingSymlinksInPath().standardizedFileURL.path
        var paths: [String] = []
        func visit(_ directory: URL, prefix: String) throws {
            for name in try FileManager.default.contentsOfDirectory(atPath: directory.path) {
                let relative = (prefix + name).precomposedStringWithCanonicalMapping; paths.append(relative)
                let url = bundle.appendingPathComponent(relative)
                if try FileSystem.metadata(url).st_mode & S_IFMT == S_IFDIR { try visit(url, prefix: relative + "/") }
            }
        }
        try visit(bundle, prefix: "")
        var inventory = Data()
        for relative in paths.sorted(by: { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }) {
            let url = bundle.appendingPathComponent(relative), s = try FileSystem.metadata(url)
            let kind: String, value: String, mode: mode_t
            switch s.st_mode & S_IFMT {
            case S_IFLNK:
                let resolved = url.resolvingSymlinksInPath().standardizedFileURL.path
                guard resolved == root || resolved.hasPrefix(root + "/") else { throw DeploymentError(4, "Lien sortant du bundle : \(relative)") }
                kind = "L"; mode = 0
                value = Data(try FileManager.default.destinationOfSymbolicLink(atPath: url.path).precomposedStringWithCanonicalMapping.utf8).base64EncodedString()
            case S_IFDIR: kind = "D"; mode = 0; value = ""
            case S_IFREG: kind = "F"; mode = s.st_mode & 0o111; value = FileSystem.hash(try Data(contentsOf: url, options: .mappedIfSafe))
            default: throw DeploymentError(4, "Objet spécial interdit : \(relative)")
            }
            inventory.append(Data("\(Data(relative.utf8).base64EncodedString())\t\(kind)\t\(mode)\t\(value)\n".utf8))
        }
        return FileSystem.hash(inventory)
    }
    static func validate(_ app: URL) throws -> PreparedRelease {
        guard !FileSystem.isSymlink(app), app.pathExtension == "app",
              let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              info["CFBundleIdentifier"] as? String == identifier,
              info["CFBundlePackageType"] as? String == "APPL",
              info["LSMinimumSystemVersion"] as? String == "14.0",
              info["CFBundleIconFile"] as? String == "AppIcon.icns",
              let name = info["CFBundleExecutable"] as? String, !name.isEmpty, !name.contains("/"),
              let version = info["CFBundleShortVersionString"] as? String,
              let build = info["CFBundleVersion"] as? String else { throw DeploymentError(4, "Bundle absent ou identité/plist non conforme : \(app.path)") }
        let binary = app.appendingPathComponent("Contents/MacOS/\(name)")
        guard access(binary.path, X_OK) == 0 else { throw DeploymentError(4, "Exécutable manquant : \(binary.path)") }
        let archs = String(decoding: try SystemCommand.run("/usr/bin/lipo", ["-archs", binary.path]), as: UTF8.self).split(whereSeparator: \.isWhitespace).map(String.init).sorted()
        guard archs == ["arm64", "x86_64"] else { throw DeploymentError(4, "App universelle arm64 et x86_64 requise.") }
        let loadCommands = String(decoding: try SystemCommand.run("/usr/bin/otool", ["-l", binary.path]), as: UTF8.self)
        let lines = loadCommands.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let minima = lines.filter { $0.hasPrefix("minos ") }.compactMap { $0.split(whereSeparator: \.isWhitespace).last }.map(String.init)
        guard minima.count == 2, minima.allSatisfy({ $0.compare("14.0", options: .numeric) != .orderedDescending }) else { throw DeploymentError(4, "Minimum système du binaire incompatible avec macOS 14.") }
        for line in lines where line.hasPrefix("path ") {
            let path = String(line.dropFirst(5)).components(separatedBy: " (offset")[0]
            if path.hasPrefix("/usr/lib/") || path.hasPrefix("/System/Library/") { continue }
            guard path.hasPrefix("@executable_path/") || path.hasPrefix("@loader_path/") else { throw DeploymentError(4, "Chemin dynamique non autonome : \(path)") }
            let relative = String(path.split(separator: "/", maxSplits: 1)[1])
            let resolved = binary.resolvingSymlinksInPath().deletingLastPathComponent().appendingPathComponent(relative).standardizedFileURL.resolvingSymlinksInPath().path
            guard resolved.hasPrefix(app.resolvingSymlinksInPath().standardizedFileURL.resolvingSymlinksInPath().path + "/") else { throw DeploymentError(4, "Chemin dynamique sortant : \(path)") }
        }
        _ = try SystemCommand.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        let signature = String(decoding: try SystemCommand.run("/usr/bin/codesign", ["-d", "--verbose=4", app.path], stderr: true), as: UTF8.self)
        guard signature.contains("Signature=adhoc"), signature.contains("runtime") else { throw DeploymentError(4, "Signature ad hoc avec runtime requise.") }
        let entitlements = try PropertyListSerialization.propertyList(from: SystemCommand.run("/usr/bin/codesign", ["-d", "--entitlements", ":-", app.path]), format: nil) as? [String: Bool]
        let expected = ["com.apple.security.app-sandbox": true, "com.apple.security.files.user-selected.read-only": true, "com.apple.security.network.client": true]
        guard entitlements == expected else { throw DeploymentError(4, "Droits effectifs non conformes.") }
        let resource = app.appendingPathComponent("Contents/Resources")
        for name in ["ReaderBase.css", "NetworkBlockRules.json", "Aide.md", "ThirdPartyNotices.txt"] {
            guard FileSystem.exists(resource.appendingPathComponent(name)) else { throw DeploymentError(4, "Ressource absente : \(name)") }
        }
        let icon = resource.appendingPathComponent("AppIcon.icns"), iconData = try Data(contentsOf: icon)
        guard iconData.prefix(4) == Data("icns".utf8), NSImage(contentsOf: icon) != nil else { throw DeploymentError(4, "Icône embarquée invalide.") }
        guard let enumerator = FileManager.default.enumerator(at: app, includingPropertiesForKeys: [.isRegularFileKey]) else { throw DeploymentError(4, "Bundle illisible.") }
        for case let url as URL in enumerator {
            if url.pathExtension == "xctest" { throw DeploymentError(4, "Bundle de tests interdit.") }
            guard !FileSystem.isSymlink(url), try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            let handle = try FileHandle(forReadingFrom: url); let header = try handle.read(upToCount: 4); try handle.close()
            guard let header, [Data([0xcf,0xfa,0xed,0xfe]), Data([0xfe,0xed,0xfa,0xcf]), Data([0xca,0xfe,0xba,0xbe]), Data([0xbe,0xba,0xfe,0xca])].contains(header) else { continue }
            let linked = String(decoding: try SystemCommand.run("/usr/bin/otool", ["-L", url.path]), as: UTF8.self)
            for line in linked.split(separator: "\n") where line.hasPrefix("\t") {
                let dependency = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " (")[0]
                guard ["/System/Library/", "/usr/lib/", "@rpath/", "@loader_path/", "@executable_path/"].contains(where: dependency.hasPrefix) else { throw DeploymentError(4, "Dépendance non autonome : \(dependency)") }
            }
        }
        return PreparedRelease(bundleIdentifier: identifier, version: version, build: build, architectures: archs, minimumOS: "14.0", sourceSHA256: sourceHash, iconSHA256: FileSystem.hash(iconData), bundleDigest: try digest(app))
    }
}
