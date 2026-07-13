#!/bin/sh
#---------------------------------------------------------------------------------
# Patches not-yet-upstreamed fixes into the PureSwift dependencies via
# `swift package edit` (used by CI; locally these edits may already exist):
#
#   - Cairo: the CFreeType system-library target declares
#     `pkgConfig: "freetype"`, but the pkg-config module is `freetype2`,
#     so SwiftPM emits no linker search path and FT_* symbols fail to link.
#
#   - Silica: `import Darwin.C.math` no longer resolves on recent macOS
#     SDKs (macOS 26); plain `import Darwin` works everywhere.
#---------------------------------------------------------------------------------
set -eux

swift package resolve

swift package edit Cairo || true
perl -pi -e 's/pkgConfig: "freetype",/pkgConfig: "freetype2",/' \
  Packages/Cairo/Package.swift

swift package edit Silica || true
find Packages/Silica/Sources -name '*.swift' \
  -exec perl -pi -e 's/import Darwin\.C\.math/import Darwin/' {} +
