# Build Pipeline

This document walks through the CI build steps, from `.circom` source to the full set of release artifacts.

---

## Overview

| Step                                                                        | What happens                                                        |
|-----------------------------------------------------------------------------|---------------------------------------------------------------------|
| [1 — Circom compilation](#step-1--circom-compilation)                       | `.circom` source compiled to C++                                    |
| [2 — Proving key generation](#step-2--proving-key-generation)               | `.r1cs` + `.ptau` → `.zkey` and `verification_key.json`             |
| [3 — Patching `main.cpp`](#step-3--the-maincpp-return-patch)                | Fix missing `return` to prevent UB infinite loop                    |
| [4 — The FFI layer](#step-4--the-ffi-layer)                                 | Common files and circuit-specific FFI layered into `{circuit}_cpp/` |
| [5 — Compilation and linking](#step-5--compilation-and-linking)             | Compile with symbol isolation                                       |
| [6 — The `.dat` file](#step-6--the-dat-file)                                | Binary circuit data embedded in the Rust crate at compile time      |
| [7 — GMP](#step-7--gmp)                                                     | Bundled static `libgmp.a` used instead of system GMP                |
| [8 — Rust build script](#step-8--rust-build-script)                         | Resolves library paths, emits Cargo link directives                 |
| [9 — Rapidsnark](#step-9--rapidsnark)                                       | Prover and verifier binaries built and bundled                      |

---

## Step 1 — Circom compilation

Produces three outputs:

- `{circuit}_cpp/` — C++ source files for the witness generator.
- `{circuit}.r1cs` — the constraint system, used for proving key generation.
- `{circuit}.dat` — binary circuit data.

---

## Step 2 — Proving key generation

The `.r1cs` from Step 1 is combined with the Hermez Powers of Tau ceremony file to produce:

- `proving_key.zkey` — Groth16 proving key, used by the prover to generate proofs.
- `verification_key.json` — used to verify proofs.

---

## Step 3 — The `main.cpp` return patch

Immediately after circom runs, the build patches `main.cpp` to insert a `return 0;` at the end of `main()`.

**Why**: The FFI layer calls circom's `main()` directly, which is already technically UB in C++ (calling `main` directly
is forbidden by the standard). On top of that, circom generates `main()` with no explicit `return` on the success path.

With `-O3`, the compiler treats the missing `return` as undefined behaviour and can optimise the entire success path
into an infinite loop.

---

## Step 4 — The FFI layer

Circom's generated C++ has no stable external API, the FFI layer adds one.
It consists of two groups of files copied into `{circuit}_cpp/` before compilation:

- **Common adapter files** (`circom_adapter`, `types`, `circom_fwd`, `assert.h`): Bridge the
  circom internals to a stable C ABI, shared across all circuits.
- **Circuit-specific entry points** (`src/{circuit}/ffi.cpp`): The public `extern "C"` functions
  that become the library's API.

```
src/
  types.hpp           → copied into {circuit}_cpp/
  circom_adapter.cpp  → copied into {circuit}_cpp/
  circom_adapter.hpp  → copied into {circuit}_cpp/
  circom_fwd.hpp      → copied into {circuit}_cpp/
  assert.h            → copied into {circuit}_cpp/
  {circuit}/
    ffi.cpp           → copied into {circuit}_cpp/{circuit}/
    ffi.hpp           → copied into {circuit}_cpp/{circuit}/
```

---

## Step 5 — Compilation and linking

### Compilation

All sources are compiled with `-Dmain=circom_main` (alongside standard flags), with bundled GMP
headers prepended before the system include path — see [Step 7](#step-7--gmp).

### Symbol isolation

All circuits compile the same internal functions (`loadCircuit`, `get_size_of_witness`, etc.) from the same source, but
with different circuit-specific constants. When multiple circuits are linked into the same binary, the linker silently
picks one definition per symbol and discards the rest, mixing constants across circuits and corrupting witness
generation.

To prevent this, every internal symbol is hidden: circuit objects are merged into a single
relocatable object, then all symbols except the two public entry points are demoted to local.
Local symbols are invisible to the final linker, so each circuit keeps its own private copy.

`fr.o` is the exception: it stays global and is added to the archive separately since it doesn't vary between circuits.

See [CONTRIBUTING.md § Symbol Isolation](../CONTRIBUTING.md#symbol-isolation-in-circuit-libraries) for the full
explanation and implementation details.

---

## Step 6 — The `.dat` file

`{circuit}.dat` (produced in Step 1) is embedded in the Rust crate at compile time.

---

## Step 7 — GMP

To standardise the GMP version used by all circuits, `libgmp.a` is built from source as part of
the CI build and placed in a `lib/` directory alongside the circuit artifacts. CI sets
include/link flags to point at the bundled GMP before any system path, ensuring it takes priority.

---

## Step 8 — Rust build script

Each `-sys` crate delegates its `build.rs` to `lbc_build`, which resolves the library paths,
links `lib{circuit}.a` and `libgmp.a` into Cargo, and re-exports the path to
`witness_generator.dat` for compile-time embedding. See [rust/README.md](../rust/README.md).

---

## Step 9 — Rapidsnark

The `prover` and `verifier` binaries are built from the rapidsnark submodule and bundled with
the release artifacts alongside the circuit libraries.

---

## Regenerating a circuit

If you change a `.circom` source file:

1. Recompile the circuit and rebuild the library.
2. Update the proving key if the R1CS changed — a changed `.circom` almost always changes the
   R1CS, which invalidates the existing `.zkey`.

If you add a new public FFI entry point to `src/{circuit}/ffi.hpp`, update `PUBLIC_SYMS` in the
Makefile. Any symbol not listed there will be localised and the linker will fail to find it.
