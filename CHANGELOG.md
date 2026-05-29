# Changelog

All notable changes to this project will be documented in this file.

## [0.5.0] — 2026-05-25

### Added

- **Circuits as static libraries** (#16)

   The central change in this release. Previously, witness generation required spawning a compiled executable per circuit.

   Each circuit is now a linkable static archive (`lib{circuit}.a`) with a stable C FFI.

   Two entry points per circuit:
  - `{circuit}_generate_witness(WitnessInput*, Bytes*)`: Generates a witness in memory from a
     JSON input string and an embedded `.dat` buffer; the caller owns the output buffer.
  - `{circuit}_generate_witness_from_files(dat, inputs, output)`: Generates a witness from a `.dat` file and a JSON
     input file, writing the witness to an output file.

   The Rust crates (`lbc-{circuit}-sys`) wrap this FFI directly and can either link against a local build or download a
   prebuilt release automatically.

   See [`rust/README.md`](rust/README.md) for usage.

- **Bundled static GMP** (#19)

   `libgmp` is now compiled from source and statically linked, removing the runtime dependency on a system GMP
   installation, and standardizing the GMP version used across all platforms.

- **Older glibc compatibility** (#21)

   Linux builds now target an older glibc ABI for broader distribution support.

- **Dual MIT/Apache-2.0 license**.

### Fixed

- **Symbol resolution conflicts** (#22, #28, #29)

   When multiple circuit libraries are linked into the same binary, the linker silently collapsed shared internal
   symbols to a single definition, corrupting witness parsing and causing SIGSEGV.

   See [CONTRIBUTING.md](CONTRIBUTING.md#symbol-isolation-in-circuit-libraries) for a full explanation and maintenance
   notes.

- **macOS C++ library linkage** (#27)

   Fixed missing C++ standard library on macOS builds.

- **Circuit assert statements** (#26)

   Assert statements in the circuit source assumed standalone binary execution, causing disruptions when compiled as a library.

- **Comparator full less-than**

   Fixed incorrect output in the full less-than comparator circuit.

### Housekeeping

- Auto-update Nix hashes on release (#25)
- Incremental builds (#20)
- Pinned CI action versions (#24)
- `rustfmt` configuration (#23)
- GMP version consistency (#31)
- String formatting fix (#30)

---

*No changelog was kept prior to v0.5.0.*
