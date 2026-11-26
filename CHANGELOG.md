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
- **PoQ**: every branch requires `pol_sl` to lie in a public window of slots, the epoch (RFC-526). The public inputs
  `pol_window_first_slot` and `pol_window_last_slot` follow `pol_t1`, and the public signals grow from 12 to 14. The
  existing ones keep their positions.
  **Breaking**: the verification key changes. The node must pass both slots, and core and proof of work provers must
  fill `pol_sl` with a slot of the window instead of arbitrary data.
- **Circuits**: built with circom 2.2.3 instead of 2.2.2, and every circuit declares `pragma circom 2.2.3`.
- **Notes**: a note is `(value, nonce, public_key, stake_public_key)`, and its commitment is
  `zkhash(NOTE_CM_V1, value, nonce, public_key, stake_public_key)`, without `program` and `data`. The private inputs
  `program` and `data` (PoL) and `pol_note_program` and `pol_note_data` (PoQ) are removed, and the input generators and
  sample inputs follow. The public signals do not change.
  **Breaking**: the note commitments, the nullifiers and the verification keys change.

### Removed

- **Constants**: `NOTE_ID_V1`, unused and absent from the specification.
- **Program Spend**: the `program_spend` circuit, its input generator, its witness generator FFI and the
  `logos-blockchain-circuits-program-spend-sys` crate.
  **Breaking**: the release bundle no longer has `program_spend/`.
- **Constants**: `NF_SK0`, `PK0`, `NOTE_NONCE_V1` and `PROGRAM_STEP_ID_V1`, used by no circuit.
- **Templates**: `derive_entropy`, `Poseidon2_sponge_hash_rate_1` and `Poseidon2_sponge_hash_rate_2`, used by no
  circuit.

### Fixed

- **Witness generation**: no longer leaks memory.

## [0.7.3] - 2026-11-12

### Changed

- **PoL** and **PoQ**: a nullifier IMT leaf is hashed as `zkhash(NULLIFIER_IMT_LEAF_V1, nullifier, next_nullifier)`,
  without the index of the leaf of the next nullifier. The inputs `low_leaf_next_index` (PoL) and
  `pol_low_leaf_next_index` (PoQ) are removed.
  **Breaking**: the node must hash its IMT leaves the same way, and the verification keys change.

## [0.7.1] - 2026-11-10

### Fixed

- **Program Spend**: the active inputs must come first, so `inputs_active[0]` holds exactly when the step consumes a
  note of the program, and the output nonces of such a step always derive from the nullifier of its first input.
  Before, a step with `inputs_active = [0, 1, 0, 0]` could pick its output nonces, and create a note of the program
  with the commitment of an existing one. The public signals do not change.
  **Breaking**: provers must put the active inputs first, and the verification key changes.
- **Transfer** and **Program Spend**: the nullifiers of the active inputs must be pairwise distinct, so one note cannot
  fill 2 inputs and be counted twice in the balance. The public signals do not change.
  **Breaking**: the verification keys change.
- **Program Spend**: the public `paid_value` is range-checked to 64 bits and the sum of the input values to 74 bits, so
  the balance `sum(inputs_value) + paid_value == sum(outputs_value)` cannot wrap around the field modulus. Before, a
  `paid_value` of `p - k` balanced outputs worth `k` less than the inputs. The public signals do not change.
  **Breaking**: the verification key changes.

## [0.7.0] - 2026-11-06

### Changed

- **Note keys**: the nullifier key `nf_sk = zkhash(NF_KDF_V1, spending_sk)` sits between the spending secret key and the
  public key `zkhash(KDF, nf_sk)`, and derives the nullifier `zkhash(NOTE_NF_V1, commitment, nf_sk)`. The note
  commitment hashes the staking key after the public key:
  `zkhash(NOTE_CM_V1, value, nonce, public_key, stake_public_key, program, data)`.
  **Breaking**: the public keys, the nullifiers, the note commitments and the verification keys change.
- **Transfer**: proves the spending secret key of each input, so `inputs_sk` becomes `inputs_spending_sk`. It takes the
  staking keys of its inputs and outputs as the private inputs `inputs_stake_pk` and `outputs_stake_pk`. The public
  signals do not change.
  **Breaking**: the private inputs and the verification key change.
- **Program Spend**: takes the staking keys of its inputs and outputs as the private inputs `inputs_stake_pk` and
  `outputs_stake_pk`. `spend_notes_hash` hashes the staking key of every input and output after its public key, `0`
  when inactive. The public signals do not change.
  **Breaking**: the private inputs and the verification key change.
- **Program Spend**: notes of the program are held by `PK0 = zkhash(KDF, NF_SK0)`, with `NF_SK0 = zkhash(NF_KDF_V1, 0)`,
  both constants of the circuit. The private input `inputs_sk` is removed. Each output flagged in `outputs_of_program`
  must have `outputs_pk` equal to `PK0`, and `program_step_id` hashes `PK0` as the public key of every active input.
  **Breaking**: the private inputs and the verification key change.
- **Program Spend**: the output `spend_notes_hash` is renamed `program_step_id`, and its DST `PROGRAM_SPEND_NOTES_V1`
  becomes `PROGRAM_STEP_ID_V1`. Its position among the public signals does not change.
  **Breaking**: its value and the verification key change.
- **PoL**: takes the nullifier key `nf_sk` and the staking secret key `staking_sk` of its note in place of `sk`, and the
  `program` and `data` of the note as private inputs, so a program note can lead like a user note. It derives the
  public key and the nullifier from `nf_sk`, and the staking key, the ticket and the entropy contribution from
  `staking_sk`, never taking the spending secret key. The leader reward note has `reward_public_key` as both its public
  key and its staking key. The public signals do not change.
  **Breaking**: the private inputs and the verification key change.
- **PoQ**: the leader branch follows the PoL. `pol_secret_key` is replaced by `pol_nullifier_key` and
  `pol_staking_secret_key`, and the note takes the private `pol_note_program` and `pol_note_data`. The key nullifier of
  a leader derives from `pol_staking_secret_key`. The core branch does not change, and `core_sk` is the nullifier key
  of the Non-ephemeral Quota Key. The public signals do not change.
  **Breaking**: the private inputs and the verification key change.

## [0.6.2] - 2026-11-05

### Changed

- **PoL**: derives the commitment of the leader reward note from the private `reward_public_key` and `reward_nonce`
  and the public input `reward_value`, with `program` and `data` at `0`, and outputs it as `reward_commitment`. The
  public signals become `[entropy_contribution, reward_commitment, sl, epoch_nonce, t0, t1, eligible_aged,
  eligible_latest, msg, reward_value]`. The PoQ does not change.
  **Breaking**: the public signals and the verification key change.

## [0.6.1] - 2026-11-03

### Changed

- **PoQ**: the leader branch proves that the note nullifier is not in the nullifier IMT of its note set when the stake
  distribution was frozen. The private inputs of the low leaf of that IMT replace `pol_nf_root_aged`.
  **Breaking**: the inputs and the verification key change.
- **Program Spend**: when the step consumes a note of the program, the nonce of each active output `i` is
  `zkhash(NOTE_NONCE_V1, nf, i, outputs_value[i], outputs_pk[i])`, where `nf` is the nullifier of the first input.
  `spend_notes_hash` reads the fields of an inactive input or output as `0`.
  **Breaking**: the output nonces, `spend_notes_hash` and the verification key change.

## [0.6.0] - 2026-10-14

Circuits of the private note ledger of Mantle: every note is private and lives in a note set, the ledger, the SDP or a
channel, each with its commitment MMR and nullifier IMT.

### Added

- **Transfer**: the `transfer` circuit and the `logos-blockchain-circuits-transfer-sys` crate. It consumes up to 4 user
  notes, creates up to 8, and outputs the excess value. Public flags mark the used inputs and outputs. The inputs are
  proven against the commitment MMR root extended with the transaction buffer.
- **Program Spend**: the `program_spend` circuit and the `logos-blockchain-circuits-program-spend-sys` crate. It
  consumes notes of a program and creates notes of the program or user notes, balancing exactly with the value paid to
  the program. It outputs `spend_notes_hash`, the hash read by the program proof. Public flags mark the outputs that
  are notes of the program.

### Changed

- **Note commitment**: gains the `program` and `data` fields.
  **Breaking**: the note commitments and the verification keys change.
- **Merkle paths**: the selectors are in the same order as their nodes, from the leaf level up. The selector of a level
  is the bit of the leaf index at that level, starting from the least significant, `1` when the path node is on the
  left.
  **Breaking**: provers must pass the selectors in this order.
- **Note sets**: each has a commitment MMR and a nullifier IMT of depth 40, and the eligible tree over the note sets has
  depth 40.
  **Breaking**: the Merkle paths and the verification keys change.
- **PoL**: proves the note commitment in the commitment MMR of its note set under the aged eligible root, and that its
  nullifier is not in the latest nullifier IMT of the same set. The ticket and the entropy contribution derive from the
  note commitment. The public input `msg`, a hash of the block header, binds the proof to its block, and replaces the
  2 `leader_pk` inputs.
  **Breaking**: the inputs, the public signals and the verification key change.
- **PoQ**: the leader branch follows the PoL, without the unspent check.
  **Breaking**: the inputs and the verification key change.

### Removed

- **PoC** and **Signature**, with the `logos-blockchain-circuits-poc-sys` and `logos-blockchain-circuits-signature-sys`
  crates.
  **Breaking**: the bundle no longer contains them.

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
