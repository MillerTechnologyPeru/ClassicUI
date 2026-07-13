#---------------------------------------------------------------------------------
# ports/3DS -- Nintendo 3DS port of ClassicUI, built with Embedded Swift.
#
# Same shape as junkbot-swift's ports/3DS: this port's source/ is compiled
# whole-module for armv6-none-none-eabi (the 3DS's ARM11 application CPU is
# an ARMv6K core), linked against libctru, and packaged as a homebrew .3dsx
# with 3dsxtool/smdhtool.
#
# The desktop SwiftUI-subset core (Sources/ClassicUICore) cannot compile
# here: Embedded Swift has no Mirror (the ViewBuilder tuple flattening), no
# untyped existentials (`any View`), no Foundation and no Observation. The
# port instead carries a small embedded mini-core (source/ClassicCore.swift)
# that reproduces the same iPod semantics -- menus, settings values, Notes
# text pages, Now Playing stacks, selection restore, scroll windowing, and
# the navigation slide -- over a software rasterizer (source/Renderer.swift)
# that draws the same classic look into the bottom LCD (320x240: the exact
# iPod Classic screen).
#
# Prerequisites:
#   - devkitPro with devkitARM and libctru (`dkp-pacman -S 3ds-dev`;
#     export DEVKITPRO=/opt/devkitpro, DEVKITARM=$DEVKITPRO/devkitARM)
#   - 3dsxtool and smdhtool (devkitPro's 3ds-tools, installed to
#     $(DEVKITPRO)/tools/bin)
#   - A Swift toolchain whose Embedded stdlib ships an armv6-none-none-eabi
#     slice
#   - python3 with Pillow (tools/gen_font.py rasterizes the UI font from the
#     host's Helvetica at build time)
#---------------------------------------------------------------------------------
.SUFFIXES:

ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>devkitpro")
endif
ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=$$DEVKITPRO/devkitARM")
endif

SWIFTC		?=	swiftc

TARGET		:=	ClassicUI
BUILD		:=	build
COMMON		:=	common/

# Override with `make CTRULIB=/path/to/libctru` to point at a libctru build
# that isn't installed under $(DEVKITPRO).
CTRULIB		?=	$(DEVKITPRO)/libctru

PREFIX		:=	$(DEVKITARM)/bin/arm-none-eabi-
CC		:=	$(PREFIX)gcc
LD		:=	$(PREFIX)gcc

3DSXTOOL	?=	3dsxtool
SMDHTOOL	?=	smdhtool
ICON		:=	$(CTRULIB)/default_icon.png

#---------------------------------------------------------------------------------
# code generation -- the 3DS's ARM11 application CPU, armv6k/mpcore, hard float.
#---------------------------------------------------------------------------------
ARCH		:=	-march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft

CTRUDEFS	:=	-D__3DS__ -I$(COMMON) -I$(CTRULIB)/include

CFLAGS		:=	-g -Wall -O2 -mword-relocations -ffunction-sections -fdata-sections \
			$(ARCH) $(CTRUDEFS)

LDFLAGS		:=	-specs=3dsx.specs -g $(ARCH) \
			-Wl,-Map,$(TARGET).map -Wl,--gc-sections \
			-L$(CTRULIB)/lib

LIBS		:=	-lctru -lm

#---------------------------------------------------------------------------------
# Embedded Swift flags, targeting armv6-none-none-eabi.
#---------------------------------------------------------------------------------
SWIFTFLAGS	:=	-target armv6-none-none-eabi \
			-enable-experimental-feature Embedded \
			-wmo -Osize \
			-module-name ClassicUI \
			-Xcc -D__3DS__ \
			-Xcc -march=armv6k -Xcc -mtune=mpcore -Xcc -mfloat-abi=hard \
			-Xcc -isystem -Xcc $(DEVKITARM)/arm-none-eabi/include \
			-Xcc -I$(COMMON) \
			-Xcc -I$(CTRULIB)/include \
			-Xcc -fmodule-map-file=$(COMMON)module.modulemap

PORT_SWIFT	:=	$(wildcard source/*.swift)
GEN_SWIFT	:=	$(BUILD)/FontAssets.swift

OFILES		:=	$(BUILD)/classicui.swift.o $(BUILD)/shim.o

#---------------------------------------------------------------------------------
.PHONY: all clean

all: $(TARGET).3dsx

$(BUILD):
	@mkdir -p $@

# Font conversion: the host's Helvetica at 13 px (the same face and size the
# desktop Silica renderer resolves) -> 1bpp variable-width glyph table.
$(BUILD)/FontAssets.swift: tools/gen_font.py | $(BUILD)
	@echo generating font assets
	python3 tools/gen_font.py $(BUILD)

# All Swift (port + generated font) -> one object, whole-module.
$(BUILD)/classicui.swift.o: $(PORT_SWIFT) $(GEN_SWIFT) \
		$(COMMON)module.modulemap $(COMMON)ctru_umbrella.h $(COMMON)shim.h | $(BUILD)
	@echo compiling Swift
	$(SWIFTC) $(SWIFTFLAGS) -c $(PORT_SWIFT) $(GEN_SWIFT) -o $@

$(BUILD)/shim.o: $(COMMON)shim.c $(COMMON)shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OFILES)
	@echo linking $(notdir $@)
	$(LD) $(LDFLAGS) $(OFILES) $(LIBS) -o $@

$(BUILD)/icon.smdh: | $(BUILD)
	@echo packaging icon
	$(SMDHTOOL) --create ClassicUI "iPod Classic UI (Embedded Swift)" "PureSwift" $(ICON) $@

$(TARGET).3dsx: $(TARGET).elf $(BUILD)/icon.smdh
	@echo packaging $(notdir $@)
	$(3DSXTOOL) $(TARGET).elf $@ --smdh=$(BUILD)/icon.smdh

clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).elf $(TARGET).3dsx $(TARGET).map
