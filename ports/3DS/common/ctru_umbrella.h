//---------------------------------------------------------------------------------
// ctru_umbrella.h -- single header exposed to Swift as the `CTRU` module.
//
// ClassicUI only needs core libctru (gfx/hid/apt) -- the iPod screen is a
// hand-rolled software rasterizer straight into the bottom LCD framebuffer
// (see source/Renderer.swift), same as junkbot-swift's ports/3DS.
//---------------------------------------------------------------------------------
#ifndef CLASSICUI_3DS_UMBRELLA_H
#define CLASSICUI_3DS_UMBRELLA_H

#include <3ds.h>
#include <stdlib.h>
#include "shim.h"

#endif // CLASSICUI_3DS_UMBRELLA_H
