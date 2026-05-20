// Assert-to-throw shim for circom-generated circuit code.
//
// Problem
// -------
// Circom generates C++ code that calls the standard assert() macro to enforce
// circuit constraints (e.g. `assert(Fr_isTrue(&expaux[0]))`). When compiled
// into a standalone binary, a failing assert aborts the subprocess and the
// caller receives a non-zero exit code; an error. When compiled into a static
// library and linked into the caller's process, the same abort kills the entire
// process. A library must never call abort() on its caller.
//
// Mechanism
// ---------
// This file is copied into each circuit's build directory as assert.h. The
// Makefile already passes -I. so the compiler finds this file before the
// system assert.h when the generated code does `#include <assert.h>`.
// #include_next <assert.h> pulls in the real system header (so all
// declarations are present), then we redefine the assert macro to throw a
// std::runtime_error instead of calling abort(). #pragma once prevents a
// second include from re-running and undoing the redefinition.
#pragma once
#include_next <assert.h>
#undef assert
#include <stdexcept>
#define assert(cond) \
    ((cond) ? void(0) : throw std::runtime_error( \
        std::string("Circuit constraint violated in ") + __FILE__ + ":" + std::to_string(__LINE__) + ": " + #cond))
