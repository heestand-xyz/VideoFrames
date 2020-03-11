// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "VideoFrames",
    products: [
        .library(name: "VideoFrames", targets: ["VideoFrames"]),
        .executable(name: "frames", targets: ["frames"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.0.1"),
    ],
    targets: [
        .target(name: "VideoFrames", dependencies: []),
        .target(name: "frames", dependencies: ["VideoFrames", "ArgumentParser"]),
        .testTarget(name: "VideoFramesTests", dependencies: ["VideoFrames"]),
    ]
)
