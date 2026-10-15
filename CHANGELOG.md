# Changelog

All notable changes to this project will be documented in this file.

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
