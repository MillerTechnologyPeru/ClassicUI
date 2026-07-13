#---------------------------------------------------------------------------------
# ports/NDS -- Nintendo DS port of ClassicUI, built with Embedded Swift.
#
# Build system modeled on MillerTechnologyPeru/swift-embedded-nds and
# junkbot-swift's ports/NDS: this port's source/ is compiled whole-module for
# armv5te-none-none-eabi (an exact match for the DS's ARM946E-S), linked
# against calico-based libnds, and packaged with ndstool using calico's
# prebuilt ARM7.
#
# The port shares its embedded mini-core and software rasterizer with
# ports/3DS (source/ClassicCore.swift is identical; source/Renderer.swift
# differs only in screen size, 256x192, and pixel format, ARGB1555) -- see
# ports/3DS/Makefile for why the desktop SwiftUI-subset core can't compile
# under Embedded Swift.
#
# Prerequisites:
#   - devkitPro with devkitARM, libnds, calico, ndstool
#     (export DEVKITPRO=/opt/devkitpro, DEVKITARM=$DEVKITPRO/devkitARM)
#   - A Swift toolchain whose Embedded stdlib ships an armv5te-none-none-eabi
#     slice. Release toolchains only ship armv4t; a recent `main` development
#     snapshot is needed. Override with `make SWIFTC=/path/to/swiftc`.
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
NDS_TITLE	:=	ClassicUI
NDS_SUBTITLE	:=	iPod Classic UI
BUILD		:=	build
COMMON		:=	common/

LIBNDS		:=	$(DEVKITPRO)/libnds
CALICO		:=	$(DEVKITPRO)/calico

PREFIX		:=	$(DEVKITARM)/bin/arm-none-eabi-
CC		:=	$(PREFIX)gcc
LD		:=	$(PREFIX)gcc

#---------------------------------------------------------------------------------
# code generation -- ARM946E-S / armv5te, soft float, no FPU.
#---------------------------------------------------------------------------------
ARCH		:=	-march=armv5te -mtune=arm946e-s -mthumb

NDSDEFS		:=	-DARM9 -D__NDS__ -I$(COMMON) \
			-I$(LIBNDS)/include -I$(CALICO)/include

CFLAGS		:=	-g -Wall -O2 -ffunction-sections -fdata-sections $(ARCH) \
			$(NDSDEFS)

LDFLAGS		:=	-specs=$(CALICO)/share/ds9.specs -g $(ARCH) \
			-Wl,-Map,$(TARGET).map -Wl,--gc-sections \
			-L$(LIBNDS)/lib -L$(CALICO)/lib

LIBS		:=	-lnds9 -lcalico_ds9 -lm

#---------------------------------------------------------------------------------
# Embedded Swift flags, targeting armv5te-none-none-eabi.
#---------------------------------------------------------------------------------
SWIFTFLAGS	:=	-target armv5te-none-none-eabi \
			-enable-experimental-feature Embedded \
			-wmo -Osize \
			-module-name ClassicUI \
			-Xcc -DARM9 -Xcc -D__NDS__ \
			-Xcc -march=armv5te -Xcc -mfloat-abi=soft \
			-Xcc -isystem -Xcc $(DEVKITARM)/arm-none-eabi/include \
			-Xcc -I$(COMMON) \
			-Xcc -I$(LIBNDS)/include \
			-Xcc -I$(CALICO)/include \
			-Xcc -fmodule-map-file=$(COMMON)module.modulemap

PORT_SWIFT	:=	$(wildcard source/*.swift)
GEN_SWIFT	:=	$(BUILD)/FontAssets.swift

OFILES		:=	$(BUILD)/classicui.swift.o $(BUILD)/shim.o

ARM7_ELF	:=	$(CALICO)/bin/ds7_maine.elf

#---------------------------------------------------------------------------------
.PHONY: all clean

all: $(TARGET).nds

$(BUILD):
	@mkdir -p $@

# Font conversion: the host's Helvetica at 13 px (the same face and size the
# desktop Silica renderer resolves) -> antialiased 8-bit-coverage glyph table.
$(BUILD)/FontAssets.swift: tools/gen_font.py | $(BUILD)
	@echo generating font assets
	python3 tools/gen_font.py $(BUILD)

# All Swift (port + generated font) -> one object, whole-module.
$(BUILD)/classicui.swift.o: $(PORT_SWIFT) $(GEN_SWIFT) \
		$(COMMON)module.modulemap $(COMMON)nds_umbrella.h $(COMMON)shim.h | $(BUILD)
	@echo compiling Swift
	$(SWIFTC) $(SWIFTFLAGS) -c $(PORT_SWIFT) $(GEN_SWIFT) -o $@

$(BUILD)/shim.o: $(COMMON)shim.c $(COMMON)shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OFILES)
	@echo linking $(notdir $@)
	$(LD) $(LDFLAGS) $(OFILES) $(LIBS) -o $@

$(TARGET).nds: $(TARGET).elf
	@echo packaging $(notdir $@)
	ndstool -c $@ -9 $(TARGET).elf -7 $(ARM7_ELF) \
		-b $(CALICO)/share/nds-icon.bmp "$(NDS_TITLE);$(NDS_SUBTITLE);swift-nds"

clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).elf $(TARGET).nds $(TARGET).map
