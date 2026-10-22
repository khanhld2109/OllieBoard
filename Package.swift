// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OllieBoard",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "OllieBoard",
            path: "Sources/OllieBoard",
            resources: [.copy("Resources/Sprites")]
        ),
        // Renders the character sprite sheet into Sources/OllieBoard/Resources.
        .executableTarget(name: "SpriteGen", path: "Sources/SpriteGen")
    ]
)
