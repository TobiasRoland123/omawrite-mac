// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Omawrite",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Omawrite", targets: ["Omawrite"])],
    targets: [
        .target(name: "OmawriteCore"),
        .executableTarget(
            name: "Omawrite",
            dependencies: ["OmawriteCore"],
            resources: [
                .copy("Resources/AppIcons"),
                .copy("Resources/Fonts"),
                .copy("Resources/Welcome.md")
            ]
        ),
        .testTarget(name: "OmawriteCoreTests", dependencies: ["OmawriteCore"]),
        .testTarget(name: "OmawriteTests", dependencies: ["Omawrite"])
    ],
    swiftLanguageModes: [.v5]
)
