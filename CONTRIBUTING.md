# Contributor's Guide

[rapidsnark]: https://github.com/logos-blockchain/logos-blockchain-rapidsnark
[rapidsnark-readme]: https://github.com/logos-blockchain/logos-blockchain-rapidsnark/blob/HEAD/README.md
[rapidsnark-contributing]: https://github.com/logos-blockchain/logos-blockchain-rapidsnark/blob/HEAD/CONTRIBUTING.md

## Development Setup

### Prerequisites

#### Sys development

- [Rust](https://rustup.rs/) — the pinned toolchain version is in `rust-toolchain.toml` and will be installed
   automatically by `rustup`.
- Compiled circuit libraries (`.a` files and `witness_generator.dat`) — see [rust/README.md](rust/README.md) for how to
   provide them.

#### Building circuits

- `llvm-objcopy` — required for symbol isolation when building circuit static libraries. On macOS, install via `brew
   install llvm` (LLVM 20+ required).

### Pre-Commit

[pre-commit](https://pre-commit.com/) covers most of the lints required by CI. It's not mandatory — you can run checks
however you like — but it's the easiest way to catch issues before pushing.

#### Installation

```bash
pre-commit install
./hooks/fmt.sh --install
```

After this, they will be run automatically on every commit.
The second command installs the nightly toolchain that the `fmt` hook uses.

#### Running Manually

To run the checks manually against all files:

```bash
pre-commit run --all-files
```

### Changelog

Every PR with a user-facing change must add an entry under `[Unreleased]` in `CHANGELOG.md`.
Group entries by [type of change](https://keepachangelog.com/en/1.1.0/#types), e.g. `Added`, `Changed` or `Fixed`.
When [releasing](#releasing), these entries move to the new version's section.

### Maintenance

#### Rust Toolchain

When bumping the stable toolchain, update `channel` in `rust-toolchain.toml`.
   Also update `[fmt].toolchain` in the same file, the nightly used by `hooks/fmt.sh` in CI and pre-commit.

#### Tool Versions

`taplo`, `cargo-deny`, and `cargo-machete` are pinned in two places that must stay in sync:

- `.pre-commit-config.yaml` (hook `rev`), except `taplo`, which is pinned in `hooks/taplo.sh` (`VERSION`)
- `.github/workflows/lint.yml` (`cargo install --version`)

---

## Building

For a full walkthrough of the CI build steps, from `.circom` source to release artifacts, see
[docs/build-pipeline.md](docs/build-pipeline.md).

### Symbol Isolation in Circuit Libraries

#### The Problem

Each circuit (PoQ, PoL, PoC, Signature) is compiled into a static archive (`libpoq.a`, `libpol.a`, etc.).
All archives share the same symbols, compiled from the same source files but with **different
constant values per circuit** (e.g. `get_size_of_witness()` returns 18149 for PoQ and 20531 for PoL).
When two or more circuit libraries are linked into the same binary, the linker silently picks the first definition it
encounters for each symbol and discards the rest without any sort of error or warning.
The result is that one circuit's constants end up hardwired into functions shared by both circuits, corrupting witness
parsing.
In practice: the wrong `get_size_of_witness()` value causes `loadCircuit` to compute an incorrect buffer size, `pu32`
walks off the end of the buffer, reads garbage as a length field, and the subsequent `memcpy` reads past the stack guard
page, which results in a **SIGSEGV**.

#### The Fix

The Makefile uses a two-step process to hide all witness-generator implementation symbols before archiving:

1. **Partial link** (`ld -r`): merges every witness-generator `.o` file into a single relocatable object.
   `fr.o` is included because its `Fr_*` symbols also appear in other native ZK libraries, such as rapidsnark, and must
   not leak into the final link.
2. **Symbol localization**: demotes every global symbol to local except the two public FFI entry
   points (`$(PROJECT)_generate_witness` and `$(PROJECT)_generate_witness_from_files`). Local
   symbols are invisible to the final linker, so each archive retains a private copy.

**`llvm-objcopy` vs GNU `objcopy`**

`llvm-objcopy` is required on Linux. GNU `objcopy` only changes the binding of COMDAT signature
symbols to local, confusing the linker's deduplication logic and causing "relocation refers to
symbol in discarded section" errors. `llvm-objcopy` additionally clears the `GRP_COMDAT` flag,
turning affected sections into regular non-COMDAT sections. Slightly larger binary, no linker errors.

##### macOS

Uses `llvm-objcopy` (from `brew install llvm`, LLVM 20+).

Mach-O prepends `_` to every C symbol, so `--keep-global-symbol` arguments must include the
leading `_`. The Makefile's `SYM_PREFIX` variable handles this automatically.

##### Windows

Uses GNU's `objcopy` (from MinGW binutils).

GNU's `objcopy` works correctly on COFF, mapping local binding to storage class `C_STAT`.
The ELF `GRP_COMDAT` problem doesn't apply: COFF COMDAT is per-section rather than group-based.

#### FFI Maintenance

`PUBLIC_SYMS` is hardcoded to `$(PROJECT)_generate_witness` and `$(PROJECT)_generate_witness_from_files` in the
Makefile. If the public FFI API ever changes — entry points renamed or new ones added — update that variable, otherwise
the affected symbols will be localized and linking will fail.

---

## Rapidsnark

The bundles ship `prover`, `verifier` and `libgmp.a` from [Logos Rapidsnark][rapidsnark]'s releases.
The circuit libraries link against this `libgmp.a`.
For details, see Logos Rapidsnark's [README][rapidsnark-readme] and [CONTRIBUTING][rapidsnark-contributing].

On Windows, these files are still built from the `rapidsnark` submodule.

### Updating

[`deps/rapidsnark/`](deps/rapidsnark) pins the Logos Rapidsnark release:

- `VERSION`: the release tag.
- `SHA256SUMS`: the SHA-256 hash of each archive of the release. CI checks every download against it.

To update both files, run:

```bash
scripts/update-rapidsnark.sh <tag>
```

---

## Releasing

Tags are `v<x.y.z>`, e.g. `v0.8.0`.
Release candidates add `-rc.<n>`.

1. Bump `version` in `rust/Cargo.toml` and `rust/Cargo.lock` in a PR.
   For a final release, also move `[Unreleased]` in `CHANGELOG.md` to a new version section, following
   [Keep a Changelog](https://keepachangelog.com/en/1.1.0/#effort).
2. Tag the merge commit and push the tag:

   ```bash
   git fetch origin
   git tag v0.8.0 origin/main
   git push origin v0.8.0
   ```

3. CI checks that the tag matches `rust/Cargo.toml`, builds and tests every platform, then creates a draft release
   with the bundles.
   Tags with `-rc` are marked as pre-releases.
4. CI commits the bundle hashes in `circuits-nix-hashes.json` to the tag's branch, then moves the tag onto that commit.
   The flake reads this file to download the release.
   Don't edit it by hand.

   > [!NOTE]
   > This fails if the branch got new commits after the tag. Then tag the new last commit with the next version,
   > e.g. `-rc.2`.

5. Review the draft and publish it.

### Releasing From a Branch

A tag on a branch other than `main` also creates a release, e.g. to test circuits before their PR merges.
The tagged commits don't reach `main`'s history after the squash merge, so CI warns on the PR.

### Release Bundles

For each supported platform (Linux x86_64, Linux aarch64, macOS aarch64, Windows x86_64), a release artifact is
generated:

**`logos-blockchain-circuits-{version}-{os}-{arch}.tar.gz`** — a complete bundle containing all components needed to
generate and verify proofs for all circuits.

**Bundle Structure:**

```text
logos-blockchain-circuits-{version}-{os}-{arch}/
├── lib/
│   └── libgmp.a
├── {circuit}/              (poc/, pol/, poq/, signature/)
│   ├── include/
│   ├── lib{circuit}.a
│   ├── proving_key.zkey
│   ├── verification_key.json
│   └── witness_generator.dat
├── prover[.exe]
├── verifier[.exe]
└── VERSION
```

> On Windows, static libraries use the `.lib` extension instead of `.a` (e.g. `pol.lib`, `gmp.lib`).

The proving keys are generated using the Hermez Powers of Tau ceremony — see [docs/build-pipeline.md § Step 2](docs/build-pipeline.md#step-2--proving-key-generation).
