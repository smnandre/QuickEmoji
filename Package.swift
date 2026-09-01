// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "QuickEmoji",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "QuickEmoji",
            path: "Sources/QuickEmoji",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "QuickEmojiTests",
            dependencies: ["QuickEmoji"],
            path: "Tests/QuickEmojiTests"
        ),
    ]
)
