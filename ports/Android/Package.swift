// swift-tools-version: 6.0
import PackageDescription

// Android build of ClassicUI. Always cross-compiled with the Swift Android SDK, e.g.:
//
//   swift build --swift-sdk aarch64-unknown-linux-android28 --product ClassicUIAndroid -c release
//
// (driven by ports/Android/Makefile, which also points pkg-config at the vendored Android SDL3
// prebuilts under Vendor/ - run scripts/fetch-sdl.sh once first). Unlike the desktop
// ClassicUI/ClassicUIDemo targets this produces a *shared library*, not an executable: on
// Android SDL's Java `SDLActivity` loads libClassicUIAndroid.so into the app process and calls
// its exported `SDL_main` (see Sources/ClassicUIAndroid/AndroidMain.swift) on a dedicated
// thread - there is no process `main`.
//
// This does not depend on ClassicUICore: PureSwift/Cairo and PureSwift/FontConfig (which
// ClassicUICore's Silica-based renderer draws through) have no Android build, so, like
// ports/3DS and ports/NDS, this port carries its own portable mini-core and software
// rasterizer (Sources/ClassicUIAndroid/ClassicCore.swift + Renderer.swift, byte-for-byte
// identical to ports/3DS's) instead. SDL3Swift is the one piece shared with the desktop
// SDL3Renderer.
let package = Package(
  name: "ClassicUIAndroid",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "ClassicUIAndroid", type: .dynamic, targets: ["ClassicUIAndroid"])
  ],
  dependencies: [
    // Same SDL3 Swift wrapper the desktop build uses. Its CSDL3 system-library target
    // resolves headers/libs through pkg-config, which the Makefile points at
    // Vendor/lib/<abi>/pkgconfig/ when cross-compiling.
    .package(url: "https://github.com/PureSwift/SDL.git", branch: "master")
  ],
  targets: [
    .target(
      name: "ClassicUIAndroid",
      dependencies: [
        .product(name: "SDL3Swift", package: "SDL")
      ]
    )
  ]
)
