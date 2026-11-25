<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- **Releases**: branches can publish dev releases, tagged `v<base>+<name>.<n>`, e.g. `v0.1.2-rc.3+feature.4`.
  Consumers can use circuits before they reach `main`. See `CONTRIBUTING.md`.
- **Releases**: release candidates, tagged `v<x.y.z>-rc.<n>` and published as pre-releases.

### Changed

- **Rapidsnark**: the bundled `prover`, `verifier` and `libgmp.a` come from
  [Logos Rapidsnark](https://github.com/logos-blockchain/logos-blockchain-rapidsnark)'s `v0.0.8-logos.1-rc.5` release,
  instead of being built from the `rapidsnark` submodule.
  Because Logos Rapidsnark builds GMP 6.3.0, the bundled GMP goes from 6.2.1 to 6.3.0.
- **Windows**: the bundle is cross-built on Linux with logos-nix's MinGW toolchain, the same toolchain as Logos
  Rapidsnark's, instead of with MSYS2.
  **Breaking**: the circuit libraries are named `lib<circuit>.a` instead of `<circuit>.lib`, and consumers must link
  them with the same toolchain.
  The bundle adds `lib/libmman.a` (mman-win32), which provides `mmap` to the circuit libraries. Consumers must link it
  too.
- **Rust**: to use the paths into the bundle on a machine that did not build the program, set `LBC_ROOT_DIR` on that
  machine to the bundle directory. These paths are the `artifacts` `*_PATH` items, and
  `logos-blockchain-circuits-rapidsnark-sys`'s `prover()` and `verifier()`.
  **Breaking**: the `artifacts` items `PROVING_KEY_PATH`, `VERIFICATION_KEY_PATH` and `CIRCUIT_DAT_PATH` are
  `LazyLock<PathBuf>` statics instead of `&str` constants.
- **Releases**: CI rejects `v<x.y.z>` and `v<x.y.z>-rc.<n>` tags that are not on `main`.

### Fixed

- **Witness generation**: frees the arrays of the main component after generating the witness, which leaked before.

## [0.5.7] - 2026-09-08

### Changed

- **PoQ**: the proof of work ticket is `zkhash(pow_nonce, pol_epoch_nonce)`, and `BLEND_POW_V1` is removed.
  **Breaking**: the verification key changes.

## [0.5.6] - 2026-08-12

### Changed

- **PoQ**: the proof of work branch takes the private `pow_nonce` in place of `pow_sk`, and drops `pow_block_hash`.
  The ticket is `zkhash(BLEND_POW_V1, pol_epoch_nonce, pow_nonce)`.
  **Breaking**: the verification key changes.

## [0.5.5] - 2026-08-05

### Changed

- **PoQ**: `pow_block_hash` is a private input instead of a public one, and the output `pow_pk` is removed.
  **Breaking**: the public signals and the verification key change.
- **PoL** and **PoQ**: the templates drop the unused slot secret tree depth parameter.

## [0.5.4] - 2026-08-04 [YANKED]

Its release assets were replaced in place with the circuits of 0.5.5, which have a different public interface, and the
release was later removed. Use 0.5.5.

### Added

- **PoQ**: proof of work branch (`selector = 2`), with the public inputs `pow_quota`, `pow_block_hash` and
  `pow_blend_difficulty`, the private `pow_sk`, and the output `pow_pk`.
  **Breaking**: the public signals and the verification key change.

### Changed

- **Releases**: the release tag points to the commit with the updated Nix hashes.

## [0.5.3] - 2026-06-09

### Fixed

- **Witness generation**: no longer leaks memory.

## [0.5.2] - 2026-06-05

### Fixed

- **Symbol isolation**: the `Fr_*` symbols are local to each circuit library, so circuits and rapidsnark can be
  linked into the same binary.

## [0.5.1] - 2026-05-30

### Removed

- **PoQ**: public input `session`. The core branch uses `pol_epoch_nonce` in its place.
  **Breaking**: the public signals and the verification key change.

## [0.5.0] — 2026-05-25

### Added

- **Circuits as static libraries**

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

- **Bundled static GMP**

   `libgmp` is now compiled from source and statically linked, removing the runtime dependency on a system GMP
   installation, and standardizing the GMP version used across all platforms.

- **Older glibc compatibility**

   Linux builds now target an older glibc ABI for broader distribution support.

- **Dual MIT/Apache-2.0 license**.

- **Rapidsnark crate**

- **Circuit artifacts exposed via macro**

### Changed

- **Single `LBC_ROOT_DIR`** replaces the separate environment variables

- **`prebuilt` is a default feature**

### Fixed

- **Symbol resolution conflicts**

   When multiple circuit libraries are linked into the same binary, the linker silently collapsed shared internal
   symbols to a single definition, corrupting witness parsing and causing SIGSEGV.

   See [CONTRIBUTING.md](CONTRIBUTING.md#symbol-isolation-in-circuit-libraries) for a full explanation and maintenance
   notes.

- **macOS C++ library linkage**

   Fixed missing C++ standard library on macOS builds.

- **Circuit assert statements**

   Assert statements in the circuit source assumed standalone binary execution, causing disruptions when compiled as a library.

- **Comparator full less-than**

   Fixed incorrect output in the full less-than comparator circuit.

- **Windows extension for rapidsnark binaries**

   The rapidsnark binaries get the `.exe` extension on Windows builds.

## [0.4.2] - 2026-03-18

### Added

- **Nix**: flake that provides the release bundles.

### Changed

- **PoQ**: the key nullifier of the leader branch is derived from the PoL slot instead of the session.

## [0.4.1] - 2026-01-22

### Added

- **Linux aarch64** builds, e.g. for the Raspberry Pi.

### Changed

- **Releases**: the bundles are named `logos-blockchain-circuits-<version>-<os>-<arch>.tar.gz` instead of
  `nomos-circuits-<version>-<os>-<arch>.tar.gz`.
  **Breaking**: consumers must download the new names.

## [0.4.0] - 2026-01-15 [YANKED]

Tagged by mistake, with the changes of 0.3.2, and never released. Use 0.4.1.

## [0.3.2] - 2026-01-15

### Changed

- **DSTs**: drop the `NOMOS_` prefix, e.g. `NOMOS_KDF` becomes `KDF`, which changes every hash that uses them.

### Removed

- **PoL** and **PoQ**: the protection against adaptive adversaries. The private `slot_secret`, `slot_secret_path` and
  `starting_slot` are replaced by `secret_key` (`pol_secret_key` in the PoQ), and `NOMOS_POL_SK_V1` is removed.

## [0.3.1] - 2025-11-18

### Changed

- **Poseidon2**: note nullifiers, public keys and reward vouchers are derived with the Poseidon2 compression
  function.

## [0.3.0] - 2025-11-17

### Changed

- **Merkle proofs**: use the Poseidon2 `Compression()` template instead of `poseidon2_hash(2)`.

## [0.2.0] - 2025-11-04

### Added

- **Releases** publish the zkeys and verification keys.

### Changed

- **Releases**: bundle all artifacts together for each supported target, as
  `nomos-circuits-<version>-<os>-<arch>.tar.gz`.

## [0.1.0] - 2025-10-06

### Added

- **Circuits**: PoC, PoL, PoQ and ZkSign, compiled and bundled.
- **Rapidsnark**: prover and verifier, compiled and bundled.
