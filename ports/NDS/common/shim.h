//---------------------------------------------------------------------------------
// shim.h -- C support for the ClassicUI NDS port.
//
// The Swift-visible surface is tiny (a fixed-arity print wrapper around
// libnds' variadic iprintf, which Embedded Swift can import but not call).
// The bulk of shim.c is runtime support referenced only by the linker:
// posix_memalign, arc4random_buf, the _swift_stdlib_strto* wrappers, and
// the __atomic_* outline helpers ARMv5TE needs (no atomic instructions on
// the ARM946E-S; see junkbot-swift's ports/NDS and
// MillerTechnologyPeru/swift-embedded-nds).
//---------------------------------------------------------------------------------
#ifndef CLASSICUI_NDS_SHIM_H
#define CLASSICUI_NDS_SHIM_H

// Print an already-formatted string (no varargs).
void nds_puts(const char *s);

#endif // CLASSICUI_NDS_SHIM_H
