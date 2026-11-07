import XCTest
@testable import InstallLocalApp

final class DeploymentTests: DeploymentTestCase {
    func testInstallRepeatAndExplicitReplacePreserveUnrelatedData() throws {
        let env = try environment(); let source = try fixture(); let newer = try fixture("new", version: "2")
        let document = root.appendingPathComponent("document.md"); try Data("# original".utf8).write(to: document)
        let preferences = root.appendingPathComponent("preferences.json")
        let preferenceBytes = Data("{\"theme\":\"dark\"}".utf8)
        try preferenceBytes.write(to: preferences)
        XCTAssertEqual(install(source, env).1, 0)
        let identity = try FileSystem.identity(env.application)
        for _ in 0..<3 { let result = install(source, env); XCTAssertEqual(result.1, 0); XCTAssertFalse(result.0.changed) }
        XCTAssertEqual(try FileSystem.identity(env.application), identity)
        XCTAssertEqual(install(newer, env).1, 2)
        XCTAssertEqual(install(newer, env, replace: true).1, 0)
        XCTAssertNotEqual(try FileSystem.identity(env.application), identity)
        XCTAssertEqual(try testValidate(env.application).version, "2")
        XCTAssertEqual(try String(contentsOf: document), "# original")
        XCTAssertEqual(try Data(contentsOf: preferences), preferenceBytes)
    }
    func testFirstInstallationURLWithoutDirectoryHintCreatesValidAlias() throws {
        var env = try environment(); let source = try fixture()
        env.application = URL(fileURLWithPath: env.application.path, isDirectory: false)
        XCTAssertEqual(install(source, env).1, 0)
        XCTAssertEqual(try DesktopAlias(desktop: env.desktop).inspect(application: env.application).state, "valide")
    }
    func testForeignObjectsAreNotReplaced() throws {
        let env = try environment(); let source = try fixture()
        try Data("étranger".utf8).write(to: env.application)
        XCTAssertEqual(install(source, env, replace: true).1, 2)
        XCTAssertEqual(try String(contentsOf: env.application), "étranger")
    }
    func testActiveApplicationBlocksReplacementButNotIdempotence() throws {
        var env = try environment(); let source = try fixture(); let newer = try fixture("new", version: "2")
        XCTAssertEqual(install(source, env).1, 0)
        env.activeProcesses = { ["123 installation canonique"] }
        XCTAssertEqual(install(newer, env, replace: true).1, 3)
        XCTAssertEqual(install(source, env).1, 0)
    }
    func testDigestMatchesPythonVector() throws {
        let folder = try directory("digest/café")
        let file = folder.appendingPathComponent("a")
        try Data("abc".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        try FileManager.default.createSymbolicLink(atPath: root.appendingPathComponent("digest/link").path, withDestinationPath: "café/a")
        let vectorURL = try XCTUnwrap(Bundle.module.url(forResource: "bundle-digest", withExtension: "json", subdirectory: "Fixtures"))
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: vectorURL)) as? [String: String]
        XCTAssertEqual(try BundleValidator.digest(root.appendingPathComponent("digest")), object?["sha256"])
    }
    func testManifestTamperingRefused() throws {
        let env = try environment(); let source = try fixture()
        try Data("modifié".utf8).write(to: source.appendingPathComponent("payload"))
        XCTAssertEqual(install(source, env).1, 4)
        XCTAssertFalse(FileSystem.exists(env.application))
    }
    func testSymlinkDestinationPreserved() throws {
        let env = try environment(); let source = try fixture()
        try FileManager.default.createSymbolicLink(at: env.application, withDestinationURL: source)
        XCTAssertEqual(install(source, env, replace: true).1, 2)
        XCTAssertTrue(FileSystem.isSymlink(env.application))
    }
}
