// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClassicUI",
    platforms: [
        // macOS 14 for the Observation framework (@Observable view models);
        // on Linux, Observation ships with the Swift toolchain
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ClassicUI",
            targets: ["ClassicUI"]
        ),
        .library(
            name: "ClassicUICore",
            targets: ["ClassicUICore"]
        ),
        .library(
            name: "ClassicUISpriteKit",
            targets: ["ClassicUISpriteKit"]
        ),
        .executable(
            name: "ClassicUIDemo",
            targets: ["ClassicUIDemo"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/Silica.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/PureSwift/SDL.git",
            branch: "master"
        )
    ],
    targets: [
        // SwiftUI-subset view layer, resolver, navigation model and the
        // Silica renderer — platform-agnostic, no SDL
        .target(
            name: "ClassicUICore",
            dependencies: [
                "Silica"
            ]
        ),
        // SDL3 presenter (window, event loop, click-wheel input)
        .target(
            name: "ClassicUI",
            dependencies: [
                .product(name: "SDL3Swift", package: "SDL"),
                "ClassicUICore"
            ]
        ),
        // SpriteKit presenter for Apple platforms (see ports/Darwin)
        .target(
            name: "ClassicUISpriteKit",
            dependencies: [
                "ClassicUICore"
            ]
        ),
        .executableTarget(
            name: "ClassicUIDemo",
            dependencies: ["ClassicUI"]
        ),
        .testTarget(
            name: "ClassicUITests",
            dependencies: ["ClassicUICore"]
        )
    ]
)
