import XCTest
@testable import InstallLocalApp

final class DesktopAliasTests: DeploymentTestCase {
    func testRealAliasResolvesNewIdentityWhileOldBundleExists() throws {
        let env = try environment(); let source = try fixture(); let newer = try fixture("new", version: "2")
        XCTAssertEqual(install(source, env).1, 0)
        var retained = env
        retained.fault = { if $0 == "cleanup" { throw DeploymentError(5, "Garder sauvegarde pour test") } }
        XCTAssertEqual(install(newer, retained, replace: true).1, 1)
        let inspection = try DesktopAlias(desktop: env.desktop).inspect(application: env.application)
        XCTAssertEqual(inspection.state, "valide")
        XCTAssertEqual(inspection.targetIdentity, try FileSystem.identity(env.application))
        XCTAssertFalse(FileSystem.isSymlink(try XCTUnwrap(inspection.url)))
        XCTAssertTrue(try XCTUnwrap(inspection.url).resourceValues(forKeys: [.isAliasFileKey]).isAliasFile == true)
    }
    func testRemoveAndRepairOnlyAliasWithoutSource() throws {
        let env = try environment(); let source = try fixture()
        XCTAssertEqual(install(source, env).1, 0)
        let before = try BundleValidator.digest(env.application)
        try FileManager.default.removeItem(at: try env.desktop().appendingPathComponent(DesktopAlias.name))
        XCTAssertEqual(Deployment(environment: env).execute(DeploymentRequest(operation: "alias")).1, 0)
        XCTAssertEqual(try BundleValidator.digest(env.application), before)
    }
    func testForeignSymlinkIsNeverReplaced() throws {
        let env = try environment(); let source = try fixture()
        let alias = try env.desktop().appendingPathComponent(DesktopAlias.name)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: source)
        XCTAssertEqual(install(source, env).1, 1)
        XCTAssertTrue(FileSystem.isSymlink(alias))
        XCTAssertEqual(Deployment(environment: env).execute(DeploymentRequest(operation: "alias")).1, 2)
    }
    func testBrokenAliasWithoutOwnershipProofIsPreserved() throws {
        let env = try environment(); let source = try fixture()
        let alien = try fixture("foreign")
        let alias = try env.desktop().appendingPathComponent(DesktopAlias.name)
        let bookmark = try alien.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
        let temporary = alias.appendingPathExtension("alias")
        try URL.writeBookmarkData(bookmark, to: temporary)
        try FileSystem.rename(temporary, alias)
        let bytes = try Data(contentsOf: alias)
        try FileManager.default.removeItem(at: alien)
        XCTAssertEqual(install(source, env).1, 1)
        XCTAssertEqual(try Data(contentsOf: alias), bytes)
    }
}
