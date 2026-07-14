#!/usr/bin/env bash
# Downloads the official libsdl-org Android release archive (the *-devel-*-android.zip asset,
# containing a prebuilt .aar) and lays its pieces out under ports/Android/Vendor/ the way
# Package.swift/Makefile/the Gradle app expect:
#
#   Vendor/include/SDL3/…                 merged C headers
#   Vendor/lib/<abi>/libSDL3.so            prebuilt shared library per ABI
#   Vendor/lib/<abi>/pkgconfig/sdl3.pc     generated so SwiftPM's pkg-config lookup
#                                          (PureSwift/SDL's CSDL3 system-library target)
#                                          resolves to this Android copy instead of Homebrew's
#                                          macOS one
#   Vendor/java/SDL3-android.jar           SDL's Java glue (SDLActivity & friends)
#   Vendor/licenses/                       upstream license texts
#
# Version matches what the desktop build uses via Homebrew (see the root README).
set -euo pipefail

SDL3_VERSION=3.4.12
ABIS=(arm64-v8a x86_64)

cd "$(dirname "$0")/.."
VENDOR="$PWD/Vendor"
DOWNLOADS="$VENDOR/downloads"
mkdir -p "$DOWNLOADS"

fetch() { # url -> cached file path on stdout
  local url="$1" file="$DOWNLOADS/$(basename "$1")"
  [ -f "$file" ] || curl -fsSL -o "$file" "$url"
  echo "$file"
}

SDL3_ZIP=$(fetch "https://github.com/libsdl-org/SDL/releases/download/release-$SDL3_VERSION/SDL3-devel-$SDL3_VERSION-android.zip")

rm -rf "$VENDOR/include" "$VENDOR/lib" "$VENDOR/java" "$VENDOR/licenses" "$VENDOR/.extract"
mkdir -p "$VENDOR/include" "$VENDOR/java" "$VENDOR/licenses" "$VENDOR/.extract"

EXTRACT="$VENDOR/.extract/sdl3"
mkdir -p "$EXTRACT"
unzip -q "$SDL3_ZIP" -d "$EXTRACT"
cp "$EXTRACT"/LICENSE.txt "$VENDOR/licenses/" 2>/dev/null || true

# The devel zip is just docs plus a prebuilt AAR; both the C headers (as a prefab module) and
# the per-ABI .so's live inside it.
AAR=$(find "$EXTRACT" -iname '*.aar' | head -1)
AAR_EXTRACT="$VENDOR/.extract/aar"
mkdir -p "$AAR_EXTRACT"
unzip -qo "$AAR" -d "$AAR_EXTRACT"
cp -R "$AAR_EXTRACT/prefab/modules/SDL3-Headers/include/." "$VENDOR/include/"
cp "$AAR_EXTRACT/classes.jar" "$VENDOR/java/SDL3-android.jar"

for abi in "${ABIS[@]}"; do
  mkdir -p "$VENDOR/lib/$abi/pkgconfig"
  cp "$AAR_EXTRACT/prefab/modules/SDL3-shared/libs/android.$abi/libSDL3.so" "$VENDOR/lib/$abi/"

  # Generate a pkg-config file SwiftPM's CSDL3 system-library target resolves against
  # (PKG_CONFIG_PATH is pointed at this directory by the Makefile).
  cat > "$VENDOR/lib/$abi/pkgconfig/sdl3.pc" <<PC
prefix=$VENDOR
includedir=\${prefix}/include
libdir=\${prefix}/lib/$abi

Name: sdl3
Description: Simple DirectMedia Layer (vendored Android prebuilt)
Version: $SDL3_VERSION
Cflags: -I\${includedir}
Libs: -L\${libdir} -lSDL3
PC
done

echo "✓ vendored SDL3 $SDL3_VERSION for ${ABIS[*]} into $VENDOR"
