// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClassicUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ClassicUI",
            targets: ["ClassicUI"]
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
        )
    ],
    targets: [
        .systemLibrary(
            name: "CSDL3",
            pkgConfig: "sdl3",
            providers: [
                .brew(["sdl3"]),
                .apt(["libsdl3-dev"])
            ]
        ),
        .target(
            name: "ClassicUI",
            dependencies: [
                "CSDL3",
                "Silica"
            ]
        ),
        .executableTarget(
            name: "ClassicUIDemo",
            dependencies: ["ClassicUI"]
        ),
        .testTarget(
            name: "ClassicUITests",
            dependencies: ["ClassicUI"]
        )
    ]
)
