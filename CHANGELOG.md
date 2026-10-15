<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
  them with the same toolchain. Consumers must also link `lib/libmman.a` (mman-win32), which the bundle now includes.
- **Rust**: to use the paths into the bundle on a machine that did not build the program, set `LBC_ROOT_DIR` on that
  machine to the bundle directory. These paths are the `artifacts` `*_PATH` items, and
  `logos-blockchain-circuits-rapidsnark-sys`'s `prover()` and `verifier()`.
  **Breaking**: the `artifacts` items `PROVING_KEY_PATH`, `VERIFICATION_KEY_PATH` and `CIRCUIT_DAT_PATH` are
  `LazyLock<PathBuf>` statics instead of `&str` constants.

### Fixed

- **Witness generation**: no longer leaks memory.

## [0.6.0] - 2026-10-14

Circuits of the private note ledger of Mantle: every note is private and lives in a note set, the ledger, the SDP or a
channel, each with its commitment MMR and nullifier IMT.

### Added

- **Transfer** (`transfer`, `lbc-transfer-sys`): consumes up to 4 user notes and creates up to 8, outputting the
  excess value. Public flags mark the used inputs and outputs, and inputs are proven against the commitment MMR root
  extended with the transaction buffer.
- **Program Spend** (`program_spend`, `lbc-program-spend-sys`): consumes notes of a program and creates notes of the
  program or user notes, balancing exactly with the value paid to the program, and outputs `spend_notes_hash`, the hash
  read by the program proof. Public flags mark the outputs that are notes of the program.

### Changed

- **Note commitment** gains the `program` and `data` fields.
- **Merkle paths** take their selectors in the same order as their nodes, from the leaf level up: the selector of a
  level is the bit of the leaf index at that level, starting from the least significant, `1` when the path node is on
  the left. Every circuit, input generator and sample input follows.
- **PoL** proves the note commitment in the commitment MMR of its note set under the aged eligible root, and the
  non-membership of its nullifier in the latest nullifier IMT of the same set. The ticket and the entropy contribution
  are derived from the note commitment. The proof is bound to its block by the public input `msg`, a hash of the block
  header, which replaces the two `leader_pk` inputs.
- **PoQ** leader branch follows the PoL, without the unspent check.
- The input generators run with plain Python 3: `just gen-inputs` replaces `just sage-run`.

### Removed

- **PoC** (`lbc-poc-sys`) and **Signature** (`lbc-signature-sys`).

## [0.5.7] - 2026-09-08

### Changed

- **PoQ**: the proof of work ticket is `Hash(pow_nonce, pol_epoch_nonce)`, without the `BLEND_POW_V1` DST.
  **Breaking**: the verification key changes.

## [0.5.6] - 2026-08-12

### Changed

- **PoQ**: the proof of work branch takes the private `pow_nonce` in place of `pow_sk`, and drops `pow_block_hash`.
  The ticket is `Hash(BLEND_POW_V1, pol_epoch_nonce, pow_nonce)`.
  **Breaking**: the verification key changes.

## [0.5.5] - 2026-08-05

### Changed

- **PoQ**: `pow_block_hash` is a private input instead of a public one, and the output `pow_pk` is removed.
  **Breaking**: the public signals and the verification key change.

## [0.5.4] - 2026-08-04 [YANKED]

Its assets were replaced with those of 0.5.5, and the release was removed. Use 0.5.5.

### Added

- **PoQ**: a proof of work branch, with the public inputs `pow_quota`, `pow_block_hash` and `pow_blend_difficulty`.
  It adds the private input `pow_sk` and the output `pow_pk`.
  **Breaking**: the public signals and the verification key change.

## [0.5.3] - 2026-06-09

### Fixed

- **Witness generation**: no longer leaks memory.

## [0.5.2] - 2026-06-05

### Fixed

- **Symbol isolation**: circuits and rapidsnark can be linked into the same binary.

## [0.5.1] - 2026-05-30

### Removed

- **PoQ**: public input `session`. The core branch uses `pol_epoch_nonce` in its place.
  **Breaking**: the public signals and the verification key change.

## [0.5.0] - 2026-05-29

### Added

- **Circuits**: each circuit is a static library (`lib{circuit}.a`) with a stable C FFI, instead of an executable
  spawned for each witness. It has 2 entry points:
  - `{circuit}_generate_witness(WitnessInput*, Bytes*)` generates a witness in memory from a JSON input string and a
    `.dat` buffer. The caller owns the output buffer.
  - `{circuit}_generate_witness_from_files(dat, inputs, output)` generates a witness from a `.dat` file and a JSON
    input file, and writes it to an output file.

  The Rust crates (`logos-blockchain-circuits-{circuit}-sys`) wrap this FFI, and can link a local build or download a
  prebuilt release. See [`rust/README.md`](rust/README.md).
  **Breaking**: consumers must link the libraries instead of running the executables.
- **GMP**: `libgmp` is compiled from source and linked statically, so no system GMP is needed, and all platforms use
  the same GMP version.
- **Linux**: builds target an older glibc ABI, for broader distribution support.
- **License**: dual MIT/Apache-2.0.
- **Rust**: the `logos-blockchain-circuits-rapidsnark-sys` crate gives the paths of the bundled `prover` and
  `verifier`.
- **Rust**: the `circuit_artifacts!` macro gives the proving key, verification key and witness generator data of a
  circuit.

### Changed

- **Rust**: `LBC_ROOT_DIR` replaces `LBC_LIB_DIR` and the variables of each circuit.
  **Breaking**: set `LBC_ROOT_DIR` instead.
- **Rust**: the `prebuilt` feature is on by default.

### Fixed

- **Symbol isolation**: when several circuit libraries were linked into the same binary, the linker collapsed their
  shared internal symbols to a single definition, which corrupted witness parsing and caused SIGSEGV. See
  [CONTRIBUTING.md](CONTRIBUTING.md#symbol-isolation-in-circuit-libraries).
- **macOS**: builds link the C++ standard library, which was missing.
- **Circuits**: `assert` statements work in the libraries.
- **Comparator**: the full less-than comparator gives the correct output.
  **Breaking**: the PoL and PoQ verification keys change.
- **PoQ**: the leader branch derives the key nullifier from the PoL slot, as 0.4.2 intended.
  **Breaking**: the verification key changes.
- **Windows**: the rapidsnark binaries have the `.exe` extension.

## [0.4.2] - 2026-03-18

### Added

- **Nix**: flake that provides the release bundles.

### Changed

- **PoQ**: the key nullifier of the leader branch is derived from the PoL slot instead of the session.
  **Breaking**: the verification key changes.

## [0.4.1] - 2026-01-21

### Added

- **Linux**: aarch64 builds, e.g. for the Raspberry Pi.

### Changed

- **Releases**: the bundles are named `logos-blockchain-circuits-<version>-<os>-<arch>.tar.gz` instead of
  `nomos-circuits-<version>-<os>-<arch>.tar.gz`.
  **Breaking**: consumers must download the new names.

## [0.4.0] - 2026-01-15 [YANKED]

Tagged by mistake, with the changes of 0.3.2, and never released. Use 0.4.1.

## [0.3.2] - 2026-01-15

### Changed

- **DSTs**: the `NOMOS_` prefix is dropped, e.g. `NOMOS_KDF` becomes `KDF`.
  **Breaking**: the hashes and the verification keys change.

### Removed

- **PoL** and **PoQ**: the protection against adaptive adversaries. The private inputs `slot_secret`,
  `slot_secret_path` and `starting_slot` are replaced by `secret_key`.
  **Breaking**: the private inputs and the verification keys change.

## [0.3.1] - 2025-11-18

### Changed

- **Poseidon2**: key nullifiers, voucher nullifiers, public keys and reward vouchers use the Poseidon2 compression
  function.
  **Breaking**: these values and the verification keys change.

## [0.3.0] - 2025-11-17

### Changed

- **Merkle proofs**: the Poseidon2 compression function replaces the Poseidon2 hash.
  **Breaking**: the Merkle roots and the verification keys change.

## [0.2.0] - 2025-11-04

### Added

- **Releases**: the zkeys and verification keys are published.

### Changed

- **Releases**: the artifacts of each target are bundled as `nomos-circuits-<version>-<os>-<arch>.tar.gz`.
  **Breaking**: consumers must download the bundles instead of the separate artifacts.

## [0.1.0] - 2025-10-06

### Added

- **Circuits**: PoC, PoL, PoQ and ZkSign, compiled and bundled.
- **Rapidsnark**: prover and verifier, compiled and bundled.
