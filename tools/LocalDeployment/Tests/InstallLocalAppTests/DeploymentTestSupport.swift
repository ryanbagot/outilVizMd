import Foundation
import XCTest
@testable import InstallLocalApp

class DeploymentTestCase: XCTestCase {
    var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("outilvizmd-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        if let root { try FileManager.default.removeItem(at: root) }
    }
    func directory(_ path: String) throws -> URL {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

extension DeploymentTestCase {
    func fixture(_ name: String = "source", version: String = "1") throws -> URL {
        let app = try directory("\(name)/outilVizMd.app")
        let contents = app.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: String] = ["CFBundleIdentifier": "com.outilvizmd.outilVizMd", "CFBundlePackageType": "APPL", "CFBundleVersion": version]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        try Data(version.utf8).write(to: app.appendingPathComponent("payload"))
        let manifest = try testValidate(app)
        try JSONEncoder().encode(manifest).write(to: app.deletingLastPathComponent().appendingPathComponent("manifest.json"))
        return app
    }
    func testValidate(_ app: URL) throws -> PreparedRelease {
        guard !FileSystem.isSymlink(app), FileSystem.exists(app),
              let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              info["CFBundleIdentifier"] as? String == "com.outilvizmd.outilVizMd",
              let version = info["CFBundleVersion"] as? String else { throw DeploymentError(4, "Bundle invalide") }
        return PreparedRelease(bundleIdentifier: "com.outilvizmd.outilVizMd", version: version, build: version,
            architectures: ["arm64", "x86_64"], minimumOS: "14.0", sourceSHA256: "fixture", iconSHA256: "fixture", bundleDigest: try BundleValidator.digest(app))
    }
    func environment() throws -> DeploymentEnvironment {
        let applications = try directory("Applications")
        let desktop = try directory("Desktop")
        return DeploymentEnvironment(application: applications.appendingPathComponent("outilVizMd.app"), desktop: { desktop }, validate: { try self.testValidate($0) }, activeProcesses: { [] })
    }
    func install(_ source: URL, _ env: DeploymentEnvironment, replace: Bool = false, dryRun: Bool = false) -> (DeploymentResult, Int32) {
        Deployment(environment: env).execute(DeploymentRequest(operation: "install", source: source, replace: replace, dryRun: dryRun))
    }
}
