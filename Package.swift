// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "KLAP", platforms: [.macOS(.v13)], products: [.executable(name: "KLAP", targets: ["KLAP"])], targets: [.target(name: "KLAPCore"), .executableTarget(name: "KLAP", dependencies: ["KLAPCore"]), .executableTarget(name: "KLAPCoreChecks", dependencies: ["KLAPCore"], path: "Tests/KLAPCoreTests")])
