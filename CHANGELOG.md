# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed

- **PoQ** input generator takes `core_sk` as the Non-ephemeral Quota Key itself, whose `zk_id` is `zkhash(KDF, core_sk)`.
  The circuit does not change.

## [0.7.1] - 2026-11-10

### Fixed

- **Program Spend** requires the active inputs to come first: an input is active only if the previous one is, so
  `inputs_active[0]` holds exactly when the step consumes a note of the program, and the nonces of the outputs of such a
  step are always derived from the nullifier of its first input. A step with `inputs_active = [0, 1, 0, 0]` could pick
  the nonces of its outputs, and create a note of the program with the commitment of an existing one. A step consuming
  no note of the program still picks the nonces of its outputs. The public signals do not change.
- **Transfer** and **Program Spend** require the nullifiers of their active inputs to be pairwise distinct
  (`DistinctWhenActive` in `misc/comparator.circom`), so one note cannot fill two inputs and be counted twice in the
  balance. The public signals do not change.
- **Program Spend** range-checks the public `paid_value` to 64 bits and the sum of its input values to 74 bits, as the
  Transfer bounds its sums, so the balance `sum(inputs_value) + paid_value == sum(outputs_value)` cannot wrap around
  the field modulus: a `paid_value` of `p - k` balanced outputs worth `k` less than the inputs. The public signals do
  not change.

## [0.7.0] - 2026-11-06

### Changed

- **Note keys**: the nullifier key `nf_sk = zkhash(NF_KDF_V1, spending_sk)` sits between the spending secret key and the
  public key `zkhash(KDF, nf_sk)`, and derives the nullifier `zkhash(NOTE_NF_V1, commitment, nf_sk)`. The note
  commitment hashes the staking key after the public key: `zkhash(NOTE_CM_V1, value, nonce, public_key,
  stake_public_key, program, data)`.
- **Transfer** proves the spending secret key of each input, `inputs_sk` becoming `inputs_spending_sk`, and takes the
  staking keys of its inputs and outputs as the private witnesses `inputs_stake_pk` and `outputs_stake_pk`. The public
  signals do not change.
- **Program Spend** takes the staking keys of its inputs and outputs as the private witnesses `inputs_stake_pk` and
  `outputs_stake_pk`, and `spend_notes_hash` hashes the staking key of every input and output after its public key,
  read as `0` when inactive. The public signals do not change.
- **Program Spend** notes of the program are held by `PK0 = zkhash(KDF, NF_SK0)`, with `NF_SK0 = zkhash(NF_KDF_V1, 0)`,
  both constants of the circuit (`misc/constants.circom`). The witness `inputs_sk` is removed: each input derives its
  commitment with `PK0` and its nullifier with `NF_SK0`, each output flagged in `outputs_of_program` must have
  `outputs_pk` equal to `PK0`, and `program_step_id` hashes `PK0` as the public key of every active input.
- **Program Spend** output `spend_notes_hash` is renamed `program_step_id`, and its domain separation tag
  `PROGRAM_SPEND_NOTES_V1` becomes `PROGRAM_STEP_ID_V1`, which changes its value and the verification key. Its position
  among the public signals does not change.
- **PoL** takes the nullifier key `nf_sk` and the staking secret key `staking_sk` of its note in place of `sk`, and the
  `program` and `data` of the note as private witnesses, so a program note leads like a user note. It derives the
  public key and the nullifier from `nf_sk`, the staking key from `staking_sk`, and the ticket and the entropy
  contribution from `staking_sk`, never taking the spending secret key. The leader reward note has `reward_public_key`
  as both its public key and its staking key. The public signals do not change.
- **PoQ** leader branch follows the PoL: `pol_secret_key` is replaced by `pol_nullifier_key` and
  `pol_staking_secret_key`, the note takes the private `pol_note_program` and `pol_note_data`, and the key nullifier of
  a leader derives from `pol_staking_secret_key`. The core branch keeps its constraints, `core_sk` being the nullifier
  key of the Non-ephemeral Quota Key. The public signals do not change, and the sample input takes the leader branch.

## [0.6.2] - 2026-11-05

### Changed

- **PoL** derives the commitment of the note of the leader reward: the private `reward_public_key` and `reward_nonce`,
  the public input `reward_value` and the public output `reward_commitment`, with `program` and `data` at `0`. The
  public signals become `[entropy_contribution, reward_commitment, sl, epoch_nonce, t0, t1, eligible_aged,
  eligible_latest, msg, reward_value]`. The PoQ does not change.

## [0.6.1] - 2026-11-03

### Changed

- **PoQ** leader branch proves the non-membership of the note nullifier in the nullifier IMT of its set when the stake
  distribution was frozen: `pol_nf_root_aged` is replaced by the witnesses of the low leaf of that IMT.
- **Program Spend** derives the nonce of each active output from the nullifier of the first input and the index of the
  output when the step consumes a note of the program, and `spend_notes_hash` reads the fields of an inactive input or
  output as `0`.

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
- **Note sets** have a commitment MMR and a nullifier IMT of depth 40, so that sustained use takes decades to fill a
  set, and the eligible tree over the note sets has depth 40, so that channel creations, each adding a note set, take
  decades to fill it. The Transfer, Program Spend, PoL and PoQ take the depth of the trees as a template parameter.
- **PoL** proves the note commitment in the commitment MMR of its note set under the aged eligible root, and the
  non-membership of its nullifier in the latest nullifier IMT of the same set. The ticket and the entropy contribution
  are derived from the note commitment. The proof is bound to its block by the public input `msg`, a hash of the block
  header, which replaces the two `leader_pk` inputs.
- **PoQ** leader branch follows the PoL, without the unspent check.
- The input generators run with plain Python 3: `just gen-inputs` replaces `just sage-run`. The PoL and PoQ
  generators derive `t0` and `t1` from the exact lottery constants of the Proof of Leadership specification.

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
