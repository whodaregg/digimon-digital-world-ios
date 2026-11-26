// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DigitalWorld",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "DigitalWorldCore", targets: ["DigitalWorldCore"])],
    targets: [
        .systemLibrary(name: "CZlib", pkgConfig: "zlib"),
        .target(name: "DigitalWorldCore", dependencies: ["CZlib"], resources: [.process("Resources")]),
        .testTarget(name: "DigitalWorldCoreTests", dependencies: ["DigitalWorldCore"])
    ],
    swiftLanguageModes: [.v5]
)
