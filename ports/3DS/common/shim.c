//---------------------------------------------------------------------------------
// shim.c -- C support for the ClassicUI 3DS port (see shim.h).
//---------------------------------------------------------------------------------
#include <3ds.h>
#include <errno.h>
#include <malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "shim.h"

//---------------------------------------------------------------------------------
// Runtime support the Embedded Swift object needs but devkitARM's newlib does
// not provide for this target (same gaps junkbot-swift's ports/3DS works
// around).
//---------------------------------------------------------------------------------

// Swift's allocator calls posix_memalign; newlib's armv6k/fpu libc only ships
// memalign (declared, but never defined).
int posix_memalign(void **memptr, size_t alignment, size_t size) {
	void *p = memalign(alignment, size);
	if (!p) return ENOMEM;
	*memptr = p;
	return 0;
}

// Embedded Swift's runtime can reference arc4random_buf (e.g. for the system
// RNG); newlib's arc4random_buf falls through to getentropy for seeding,
// which libctru doesn't implement. Supply a small xorshift PRNG as the
// missing entropy source. NOT cryptographically secure -- nothing in this
// port relies on randomness at all.
static uint32_t s_entropyState = 0x2545F491u;

int getentropy(void *buf, size_t buflen) {
	uint8_t *p = (uint8_t *)buf;
	for (size_t i = 0; i < buflen; i++) {
		s_entropyState ^= s_entropyState << 13;
		s_entropyState ^= s_entropyState >> 17;
		s_entropyState ^= s_entropyState << 5;
		p[i] = (uint8_t)s_entropyState;
	}
	return 0;
}

// Some newlib configurations call the reentrant form directly; the first
// parameter is an unused `struct _reent *`.
int _getentropy_r(void *reent, void *buf, size_t buflen) {
	(void)reent;
	return getentropy(buf, buflen);
}

void ctru_puts(const char *s) {
	printf("%s", s);
}

//---------------------------------------------------------------------------------
// Screen present -- see shim.h for why this transposes. Each screen swaps
// independently (gfxScreenSwapBuffers): the bottom (iPod screen) redraws
// every dirty frame while the top (banner) is drawn once with double
// buffering disabled.
//---------------------------------------------------------------------------------
static void presentScreen(gfxScreen_t screen, const uint16_t *canvas, int width, int height) {
	u16 fbWidth = 0, fbHeight = 0;
	uint16_t *fb = (uint16_t *)gfxGetFramebuffer(screen, GFX_LEFT, &fbWidth, &fbHeight);
	if (!fb) return;

	// fbWidth/fbHeight are the *physical* (portrait) dimensions -- fbWidth is
	// our canvas's height and vice versa. Pixel (x,y) in our landscape canvas
	// lands at column x, row (height-1-y) of the column-major hardware buffer.
	for (int y = 0; y < height; y++) {
		const uint16_t *srcRow = canvas + y * width;
		int dstRow = height - 1 - y;
		for (int x = 0; x < width; x++) {
			fb[x * height + dstRow] = srcRow[x];
		}
	}

	gfxFlushBuffers();
	gfxScreenSwapBuffers(screen, true);
}

void ctru_present_bottom(const uint16_t *canvas, int width, int height) {
	presentScreen(GFX_BOTTOM, canvas, width, height);
}

void ctru_present_top(const uint16_t *canvas, int width, int height) {
	presentScreen(GFX_TOP, canvas, width, height);
}
