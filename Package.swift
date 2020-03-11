// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "VideoFrames",
    platforms: [
        .macOS(.v10_11),
        .iOS(.v9)
    ],
    products: [
        .library(name: "VideoFrames", targets: ["VideoFrames"]),
        .executable(name: "VideoToFrames", targets: ["VideoToFrames"]),
        .executable(name: "FramesToVideo", targets: ["FramesToVideo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.0.1"),
    ],
    targets: [
        .target(name: "VideoFrames", dependencies: []),
        .target(name: "VideoToFrames", dependencies: ["VideoFrames", "ArgumentParser"]),
        .target(name: "FramesToVideo", dependencies: ["VideoFrames", "ArgumentParser"]),
        .testTarget(name: "VideoFramesTests", dependencies: ["VideoFrames"]),
    ]
)
