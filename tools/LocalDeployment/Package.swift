// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalDeployment",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "install-local-app", targets: ["InstallLocalApp"])],
    targets: [
        .executableTarget(name: "InstallLocalApp"),
        .testTarget(name: "InstallLocalAppTests", dependencies: ["InstallLocalApp"], resources: [.copy("Fixtures")])
    ]
)
