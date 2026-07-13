//---------------------------------------------------------------------------------
// nds_umbrella.h -- single header exposed to Swift as the `NDS` module.
//
// Trimmed from MillerTechnologyPeru/swift-embedded-nds's umbrella: ClassicUI
// only needs core libnds (video/backgrounds/input) -- the iPod screen is a
// software rasterizer into a 16bpp bitmap background (source/Renderer.swift),
// same shape as junkbot-swift's ports/NDS.
//---------------------------------------------------------------------------------
#ifndef CLASSICUI_NDS_UMBRELLA_H
#define CLASSICUI_NDS_UMBRELLA_H

#include <nds.h>
#include <stdlib.h>
#include "shim.h"

#endif // CLASSICUI_NDS_UMBRELLA_H
