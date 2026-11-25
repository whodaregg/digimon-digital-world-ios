// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DigitalWorld",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "DigitalWorldCore", targets: ["DigitalWorldCore"])],
    targets: [
        .target(name: "DigitalWorldCore", resources: [.process("Resources")]),
        .testTarget(name: "DigitalWorldCoreTests", dependencies: ["DigitalWorldCore"])
    ],
    swiftLanguageModes: [.v5]
)
