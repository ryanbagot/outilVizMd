import XCTest
import AppKit
@testable import InstallLocalApp

final class InstalledLaunchTests: XCTestCase {
    @MainActor func testExplicitInstalledBundleReusesProcess() async throws {
        guard let path = ProcessInfo.processInfo.environment["OUTILVIZMD_TEST_INSTALLED_APP"] else {
            throw XCTSkip("Recette système opt-in : OUTILVIZMD_TEST_INSTALLED_APP requis ; aucune app personnelle lancée par défaut.")
        }
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let prepared = try BundleValidator.validate(url)
        var pid: pid_t?
        for _ in 0..<10 {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = false
            configuration.allowsRunningApplicationSubstitution = false
            let application = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            XCTAssertEqual(application.bundleURL?.resolvingSymlinksInPath(), url)
            if let pid { XCTAssertEqual(application.processIdentifier, pid) }
            pid = application.processIdentifier
            XCTAssertEqual(try BundleValidator.validate(url).version, prepared.version)
        }
    }
}
