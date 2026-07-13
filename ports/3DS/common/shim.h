//---------------------------------------------------------------------------------
// shim.h -- C support for the ClassicUI 3DS port.
//
// Two jobs (a subset of junkbot-swift's ports/3DS shim -- no audio here):
//   1. Runtime symbols the Embedded Swift object needs but devkitARM's
//      newlib does not provide for this target (see shim.c).
//   2. A software-rasterizer present step: both LCDs' framebuffers are
//      stored column-major (physically portrait panels rotated for
//      landscape display), so writing our row-major canvases straight into
//      them would come out sideways -- ctru_present_bottom/top transpose.
//---------------------------------------------------------------------------------
#ifndef CLASSICUI_3DS_SHIM_H
#define CLASSICUI_3DS_SHIM_H

#include <stdint.h>

// Print an already-formatted string (no varargs, which Embedded Swift can
// import but not call).
void ctru_puts(const char *s);

// Transposes `canvas` (320x240, row-major, RGB565) into the bottom screen's
// current hardware framebuffer (240x320, column-major) and flips it.
void ctru_present_bottom(const uint16_t *canvas, int width, int height);

// Transposes `canvas` (400x240, row-major, RGB565) into the top screen's
// current hardware framebuffer (240x400, column-major) and flips it. Call
// only when the top screen's content actually changed -- Main.swift disables
// its double buffering at startup, so a write sticks until the next one.
void ctru_present_top(const uint16_t *canvas, int width, int height);

#endif // CLASSICUI_3DS_SHIM_H
