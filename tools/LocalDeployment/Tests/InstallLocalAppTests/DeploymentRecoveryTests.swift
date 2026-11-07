import XCTest
import Darwin
@testable import InstallLocalApp

final class DeploymentRecoveryTests: DeploymentTestCase {
    func testFailuresRestoreOldBundleAndAlias() throws {
        for point in ["copy", "commit", "postCommit"] {
            let env = try environment(); let source = try fixture("source-\(point)"); let newer = try fixture("new-\(point)", version: "2")
            XCTAssertEqual(install(source, env).1, 0)
            let oldID = try FileSystem.identity(env.application)
            var failing = env
            failing.fault = { if $0 == point { throw DeploymentError(6, "Panne \(point)") } }
            XCTAssertEqual(install(newer, failing, replace: true).1, 6)
            XCTAssertEqual(try FileSystem.identity(env.application), oldID)
            XCTAssertEqual(try DesktopAlias(desktop: env.desktop).inspect(application: env.application).state, "valide")
        }
    }
    func testRollbackFailureKeepsRecoveryAndBlocksFurtherMutations() throws {
        var env = try environment(); let source = try fixture(); let newer = try fixture("new", version: "2")
        XCTAssertEqual(install(source, env).1, 0)
        env.fault = { if ["postCommit", "rollback"].contains($0) { throw DeploymentError(6, "Panne") } }
        let result = install(newer, env, replace: true)
        XCTAssertEqual(result.1, 8); XCTAssertFalse(result.0.recoveryPaths.isEmpty)
        env.fault = { _ in }
        XCTAssertEqual(install(newer, env, replace: true).1, 8)
        let status = Deployment(environment: env).execute(DeploymentRequest(operation: "status"))
        XCTAssertEqual(status.1, 0); XCTAssertFalse(status.0.recoveryPaths.isEmpty)
    }
    func testCleanupFailureIsPartial() throws {
        var env = try environment(); let source = try fixture()
        env.fault = { if $0 == "cleanup" { throw DeploymentError(5, "Nettoyage refusé") } }
        let result = install(source, env)
        XCTAssertEqual(result.1, 1); XCTAssertEqual(result.0.applicationState, "valide")
        XCTAssertFalse(result.0.recoveryPaths.isEmpty)
    }
    func testLateForeignDestinationIsPreserved() throws {
        var env = try environment(); let source = try fixture(); let app = env.application
        env.fault = { if $0 == "commit" { try Data("concurrent".utf8).write(to: app) } }
        XCTAssertNotEqual(install(source, env).1, 0)
        XCTAssertEqual(try String(contentsOf: app), "concurrent")
    }
    func testConcurrentInvocationIsRefused() throws {
        let env = try environment(); let source = try fixture()
        let deployment = Deployment(environment: env)
        let fd = try deployment.lock()
        defer { flock(fd, LOCK_UN); close(fd) }
        XCTAssertEqual(install(source, env).1, 7)
        XCTAssertFalse(FileSystem.exists(env.application))
    }
    func testForeignAliasDuringRollbackIsNotOverwritten() throws {
        var env = try environment(); let source = try fixture(); let newer = try fixture("new", version: "2")
        XCTAssertEqual(install(source, env).1, 0)
        let alias = try env.desktop().appendingPathComponent(DesktopAlias.name)
        env.fault = { point in
            if point == "postCommit" {
                try Data("concurrent".utf8).write(to: alias)
                throw DeploymentError(6, "Validation échouée")
            }
        }
        let result = install(newer, env, replace: true)
        XCTAssertEqual(result.1, 8)
        XCTAssertEqual(try String(contentsOf: alias), "concurrent")
        XCTAssertEqual(try testValidate(env.application).version, "1")
    }

}
