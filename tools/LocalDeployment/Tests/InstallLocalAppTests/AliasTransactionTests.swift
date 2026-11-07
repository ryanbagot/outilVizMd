import XCTest
@testable import InstallLocalApp

final class AliasTransactionTests: DeploymentTestCase {
    func testDesktopUnavailableFirstInstallPartialUpdateRefused() throws {
        var env = try environment(); let source = try fixture(); let newer = try fixture("new", version: "2")
        env.desktop = { throw DeploymentError(5, "Bureau inaccessible") }
        XCTAssertEqual(install(source, env).1, 1)
        XCTAssertEqual(install(newer, env, replace: true).1, 5)
        XCTAssertEqual(try testValidate(env.application).version, "1")
    }
    func testAliasFailureAfterCommitDoesNotUndoValidApplication() throws {
        var env = try environment(); let source = try fixture()
        env.fault = { if $0 == "alias" { throw DeploymentError(5, "Alias refusé") } }
        let result = install(source, env)
        XCTAssertEqual(result.1, 1); XCTAssertEqual(result.0.applicationState, "valide")
        XCTAssertEqual(result.0.aliasState, "absent")
    }
    func testAliasCannotBeSecuredPreventsCommit() throws {
        var env = try environment(); let source = try fixture(); let newer = try fixture("new", version: "2")
        XCTAssertEqual(install(source, env).1, 0)
        env.fault = { if $0 == "secureAlias" { throw DeploymentError(5, "Refus") } }
        XCTAssertEqual(install(newer, env, replace: true).1, 5)
        XCTAssertEqual(try testValidate(env.application).version, "1")
    }
}
