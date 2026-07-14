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
            url: "https://github.com/PureSwift/Cairo.git",
            branch: "master"
        ),
        // Pinned to a specific revision rather than floating on "master":
        // Silica's master branch split into a multi-backend architecture
        // (CGContext became a protocol, with the concrete Cairo-backed
        // type moved to a separate SilicaCairo library/target) after this
        // revision, which breaks ClassicRenderer.swift's direct
        // `Silica.CGContext(surface:size:)` construction. Floating deps
        // otherwise silently re-resolve to a breaking upstream commit
        // whenever this manifest changes for an unrelated reason.
        .package(
            url: "https://github.com/PureSwift/Silica.git",
            revision: "fa20973dc7eb1dd90c2541943c05abbc5873e7f6"
        ),
        .package(
            url: "https://github.com/PureSwift/SDL.git",
            branch: "master"
        )
    ],
    targets: [
        // SwiftUI-subset view layer, resolver, navigation model and the
        // Silica renderer — platform-agnostic, no SDL. ClassicRenderer.swift
        // draws directly against Cairo's CGContext-style API (not just
        // Silica's), so Cairo needs to be declared here too.
        .target(
            name: "ClassicUICore",
            dependencies: [
                "Silica",
                "Cairo"
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
