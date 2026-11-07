import XCTest
@testable import InstallLocalApp

final class CommandTests: DeploymentTestCase {
    func testStrictArguments() throws {
        XCTAssertTrue(try Command.parse(["install", "--source", "/tmp/example.app", "--replace", "--json"]).replace)
        for args in [["status", "--source", "/tmp/a"], ["alias", "--replace"], ["status", "--dry-run"], ["install"], ["install", "--source", "/tmp/a", "--destination", "/tmp/b"], ["status", "--json", "--json"]] {
            XCTAssertThrowsError(try Command.parse(args)) { XCTAssertEqual(($0 as? DeploymentError)?.code, 64) }
        }
    }
    func testStatusAndDryRunNeverWrite() throws {
        let env = try environment(); let source = try fixture()
        let before = try BundleValidator.digest(root)
        let status = Deployment(environment: env).execute(DeploymentRequest(operation: "status"))
        XCTAssertEqual(status.1, 0); XCTAssertEqual(status.0.applicationState, "absent")
        let preview = install(source, env, dryRun: true)
        XCTAssertEqual(preview.1, 0); XCTAssertEqual(preview.0.outcome, "preview")
        XCTAssertEqual(try BundleValidator.digest(root), before)
        let object = try JSONSerialization.jsonObject(with: Command.json(preview.0)) as? [String: Any]
        XCTAssertEqual(object?["schemaVersion"] as? Int, 1)
        XCTAssertNotNil(object?["plannedActions"])
    }
}
