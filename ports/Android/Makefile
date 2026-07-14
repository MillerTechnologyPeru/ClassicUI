# Android build. End to end:
#
#   make vendor    # once: download the SDL3 Android prebuilt into Vendor/
#   make apk       # generate font + cross-compile Swift -> stage native libs -> gradle assembleDebug
#   make install   # adb install + launch on the connected device/emulator
#
# Prereqs: the Swift Android SDK (`swift sdk list` should show a *_android entry), an Android
# NDK (r27+) under ~/Library/Android/sdk/ndk (the ndk-sysroot link is set up automatically), an
# Android SDK + JDK for the Gradle step, and python3 with Pillow (tools/gen_font.py).

# arm64-v8a (default) or x86_64 (Intel-hosted emulators).
ABI ?= arm64-v8a
ifeq ($(ABI),arm64-v8a)
SWIFT_ARCH := aarch64
else ifeq ($(ABI),x86_64)
SWIFT_ARCH := x86_64
else
$(error unsupported ABI '$(ABI)' - use arm64-v8a or x86_64)
endif
API_LEVEL ?= 28
TRIPLE    := $(SWIFT_ARCH)-unknown-linux-android$(API_LEVEL)

VENDOR     := $(CURDIR)/Vendor
SDK_BUNDLE := $(wildcard $(HOME)/Library/org.swift.swiftpm/swift-sdks/swift-*-RELEASE_android.artifactbundle/swift-android)
NDK_HOME   ?= $(lastword $(sort $(wildcard $(HOME)/Library/Android/sdk/ndk/*)))

.PHONY: vendor sysroot font build jnilibs apk install clean

vendor:
	scripts/fetch-sdl.sh

# The Swift Android SDK ships without NDK headers/libs; its setup script links them in from a
# locally installed NDK (idempotent, re-run only when ndk-sysroot is missing).
sysroot:
	@if [ ! -d "$(SDK_BUNDLE)/ndk-sysroot" ]; then \
		ANDROID_NDK_HOME="$(NDK_HOME)" "$(SDK_BUNDLE)/scripts/setup-android-sdk.sh"; \
	fi

# Font conversion: the host's Helvetica at 13 px (the same face and size the desktop Silica
# renderer resolves) -> antialiased 8-bit-coverage glyph table, written straight into the
# SwiftPM target's source directory so `swift build` picks it up like any other source file.
font:
	@echo generating font assets
	python3 tools/gen_font.py Sources/ClassicUIAndroid

# PKG_CONFIG_PATH + the explicit -Xcc/-Xlinker flags both point at Vendor/ so PureSwift/SDL's
# CSDL3 system-library target resolves to the Android prebuilt (never Homebrew's macOS one).
build: sysroot font
	PKG_CONFIG_PATH=$(VENDOR)/lib/$(ABI)/pkgconfig \
	swift build --swift-sdk $(TRIPLE) --product ClassicUIAndroid -c release \
		-Xcc -I$(VENDOR)/include -Xlinker -L$(VENDOR)/lib/$(ABI)

jnilibs: build
	scripts/stage-jnilibs.sh $(ABI) $(TRIPLE) $(SWIFT_ARCH)

# Prefer Android Studio's bundled JDK for Gradle: AGP's jlink-based android.jar transform
# chokes on very new JDKs (e.g. Homebrew's OpenJDK 26).
JBR := /Applications/Android Studio.app/Contents/jbr/Contents/Home
apk: jnilibs
	ANDROID_HOME=$${ANDROID_HOME:-$(HOME)/Library/Android/sdk} \
	JAVA_HOME="$$( [ -d '$(JBR)' ] && echo '$(JBR)' || echo "$$JAVA_HOME" )" \
	gradle -p AndroidApp :app:assembleDebug
	@echo "✓ APK at AndroidApp/app/build/outputs/apk/debug/app-debug.apk"

install: apk
	adb install -r AndroidApp/app/build/outputs/apk/debug/app-debug.apk
	adb shell am start -n org.pureswift.classicui/.MainActivity

clean:
	rm -rf .build AndroidApp/app/build AndroidApp/.gradle AndroidApp/app/src/main/jniLibs Sources/ClassicUIAndroid/FontAssets.swift
