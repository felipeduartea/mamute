// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Mamute",
    platforms: [.macOS("14.2")],
    targets: [
        .target(name: "MamuteCore"),
        .executableTarget(name: "Mamute", dependencies: ["MamuteCore"]),
        .testTarget(name: "MamuteCoreTests", dependencies: ["MamuteCore"]),
    ],
    swiftLanguageModes: [.v5]
)
