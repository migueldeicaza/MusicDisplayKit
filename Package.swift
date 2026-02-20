// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MusicDisplayKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "MusicDisplayKit", targets: ["MusicDisplayKit"]),
        .library(name: "MusicDisplayKitCore", targets: ["MusicDisplayKitCore"]),
        .library(name: "MusicDisplayKitModel", targets: ["MusicDisplayKitModel"]),
        .library(name: "MusicDisplayKitMusicXML", targets: ["MusicDisplayKitMusicXML"]),
        .library(name: "MusicDisplayKitLayout", targets: ["MusicDisplayKitLayout"]),
        .library(name: "MusicDisplayKitVexAdapter", targets: ["MusicDisplayKitVexAdapter"]),
    ],
    dependencies: [
        .package(path: "../work/VexFoundation"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
    ],
    targets: [
        .target(name: "MusicDisplayKitCore"),
        .target(
            name: "MusicDisplayKitModel",
            dependencies: ["MusicDisplayKitCore"]
        ),
        .target(
            name: "MusicDisplayKitMusicXML",
            dependencies: [
                "MusicDisplayKitCore",
                "MusicDisplayKitModel",
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ]
        ),
        .target(
            name: "MusicDisplayKitLayout",
            dependencies: [
                "MusicDisplayKitCore",
                "MusicDisplayKitModel",
            ]
        ),
        .target(
            name: "MusicDisplayKitVexAdapter",
            dependencies: [
                "MusicDisplayKitCore",
                "MusicDisplayKitModel",
                "MusicDisplayKitLayout",
                .product(name: "VexFoundation", package: "VexFoundation"),
            ]
        ),
        .target(
            name: "MusicDisplayKit",
            dependencies: [
                "MusicDisplayKitCore",
                "MusicDisplayKitModel",
                "MusicDisplayKitMusicXML",
                "MusicDisplayKitLayout",
                "MusicDisplayKitVexAdapter",
            ]
        ),
        .testTarget(
            name: "MusicDisplayKitTests",
            dependencies: [
                "MusicDisplayKit",
                "MusicDisplayKitCore",
                "MusicDisplayKitModel",
                "MusicDisplayKitMusicXML",
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ]
        ),
    ]
)
