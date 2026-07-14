# ClassicUI for Android

A native Swift Android port of the iPod Classic UI, built as a shared library
loaded by SDL's Java `SDLActivity` — no JNI bootstrap, no Java UI code beyond
the `SDLActivity` subclass in `AndroidApp/`.

## Why this isn't ClassicUICore

[PureSwift/Cairo](https://github.com/PureSwift/Cairo) and
[PureSwift/FontConfig](https://github.com/PureSwift/FontConfig) — which the
desktop SwiftUI-subset resolver (`ClassicUICore`, via Silica) renders
through — have no Android build: there is no prebuilt libcairo/libfontconfig
for the Android NDK, and cross-building the whole
Cairo/FreeType/FontConfig/libpng stack from source for Android is out of
scope for this port.

So, like the `ports/3DS` and `ports/NDS` console ports (which hit the same
wall under Embedded Swift, for different reasons — no `Mirror`, no
existentials, no Foundation there), this port carries its own portable
mini-core and software rasterizer instead of `ClassicUICore`:

- `Sources/ClassicUIAndroid/ClassicCore.swift` is byte-for-byte identical to
  `ports/3DS`'s — the same menu/settings/Notes/Now Playing/navigation model.
- `Sources/ClassicUIAndroid/Renderer.swift` is the same rasterizer adapted to
  32bpp ARGB8888 (the 3DS/NDS ports use RGB565/ARGB1555 for their LCD
  framebuffers; Android's SDL streaming texture takes ARGB8888 directly, so
  no per-pixel format conversion or transposition is needed at present time).
- `tools/gen_font.py` is the same build-time Helvetica rasterizer.

Unlike the console ports, though, this one *does* share
[PureSwift/SDL](https://github.com/PureSwift/SDL)'s `SDL3Swift` with the
desktop `SDL3Renderer` — SDL3 has a real, official Android build (prebuilt
`.aar`), and cross-compiles cleanly with the
[Swift Android SDK](https://github.com/swift-android-sdk). No JNI, no
`swift-android-native`, no bundled assets: the font is compiled in as Swift
arrays, exactly like the console ports, so there's nothing to extract from
the APK at first launch.

## Controls

| Input | Action |
|---|---|
| D-pad / gamepad up-down | rotate the click wheel |
| Gamepad A | select |
| Gamepad B, system Back gesture | Menu (back) |
| Gamepad X/Y/Start | play/pause |
| Gamepad D-pad left/right, shoulders | previous/next track |
| Tap top third of the screen | scroll up |
| Tap bottom third of the screen | scroll down |
| Tap the middle third | select |

## Building

Prerequisites:

- The [Swift Android SDK](https://github.com/swift-android-sdk) installed
  (`swift sdk list` should show a `*_android` entry) and a matching Swift
  toolchain (the SDK's Swift module format is toolchain-version-pinned —
  install the exact release via [swiftly](https://swift.org/swiftly), e.g.
  `swiftly install 6.3.2 && swiftly use 6.3.2`, and select it for the shell
  with `export TOOLCHAINS=swift-6.3.2-RELEASE` on macOS)
- An Android NDK (r27+) under `~/Library/Android/sdk/ndk`
- An Android SDK + JDK for the Gradle step
- python3 with Pillow (`tools/gen_font.py`)

```sh
cd ports/Android
make vendor   # once: downloads the SDL3 Android prebuilt into Vendor/
make apk      # generates the font, cross-compiles, stages native libs, gradle assembleDebug
make install  # adb install + launch on a connected device/emulator
```

`ABI=x86_64 make apk` builds for the Intel-hosted emulator ABI instead of
`arm64-v8a` (the default).

## Status

Verified: builds a real `arm64-v8a` shared library (`libClassicUIAndroid.so`,
linked against the vendored SDL3 prebuilt) whose Swift-runtime `DT_NEED`
closure resolves cleanly against the Swift Android SDK, staged alongside
SDL's Java glue into a signed debug APK via Gradle. Not yet run on a device
or in an emulator.
