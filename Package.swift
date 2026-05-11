// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WildStackUpdater",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "WildStackUpdater",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/WildStackUpdater",
            exclude: [
                // Info.plist cannot be a SPM bundle resource.
                // Add SUFeedURL + SUPublicEDKey in Xcode → Target → Info when building for distribution.
                "Resources/Info.plist",
            ],
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
