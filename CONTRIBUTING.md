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

### Pull Requests

PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/), e.g.
`feat(poq): add a slot window`. CI checks this.
PRs are squash-merged, so the title becomes the commit message on `main`.
Commit messages inside a PR are free-form.

### Changelog

Every PR with a user-facing change must add an entry under `[Unreleased]` in `CHANGELOG.md`.
Group entries by [type of change](https://keepachangelog.com/en/1.1.0/#types), e.g. `Added`, `Changed` or `Fixed`.
Mark a breaking change with a `**Breaking**: ...` line that says what consumers must change.
When [releasing](#releasing), these entries move to the new version's section.

CI, tooling and other internal changes don't go in the changelog.
Don't add PR numbers to entries: you often write the entry before the PR exists, and "What's Changed" links every PR.

### Maintenance

#### Rust Toolchain

When bumping the stable toolchain, update `channel` in `rust-toolchain.toml`.
   Also update `[fmt].toolchain` in the same file, the nightly used by `hooks/fmt.sh` in CI and pre-commit.

#### Submodules

When you update the `circomlib` submodule, set the same commit in its `flake.nix` input and run `nix flake lock`.
They must match, so that all builds use the same version of `circomlib`.
CI checks that they match.

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

Each circuit (PoL, PoQ, Transfer) is compiled into a static archive (`libpol.a`, `libpoq.a`, etc.).
All archives share the same symbols, compiled from the same source files but with **different
constant values per circuit** (e.g. `get_size_of_witness()` returns 20531 for PoL and 18149 for PoQ).
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

Uses `isolate_symbols.sh` instead of `ld -r` and `objcopy`.

On Windows, `ld -r` and `objcopy` also make COMDAT symbols local, e.g. template instances, so the link with `libstdc++`
fails.
The script renames each internal symbol to `__<project>_priv_<symbol>` instead.
It keeps the public FFI symbols and the COMDAT symbols.

#### FFI Maintenance

`PUBLIC_SYMS` is hardcoded to `$(PROJECT)_generate_witness` and `$(PROJECT)_generate_witness_from_files` in the
Makefile. If the public FFI API ever changes — entry points renamed or new ones added — update that variable, otherwise
the affected symbols will be localized and linking will fail.

---

## Rapidsnark

The bundles ship `prover`, `verifier` and `libgmp.a` from [Logos Rapidsnark][rapidsnark]'s releases.
The circuit libraries link against this `libgmp.a`.
For details, see Logos Rapidsnark's [README][rapidsnark-readme] and [CONTRIBUTING][rapidsnark-contributing].

### Updating

The Logos Rapidsnark release is pinned in 3 places:

- `deps/rapidsnark/VERSION`: the release tag.
- `deps/rapidsnark/SHA256SUMS`: the SHA-256 hash of each archive of the release. CI checks every download against it.
- The `logos-blockchain-rapidsnark` input in `flake.nix`: the Windows build uses it.

To update all 3, run:

```bash
scripts/update_rapidsnark.sh <tag>
```

---

## Releasing

There are 3 kinds of release:

| Kind              | Tag                  | Source     | Promise                           |
|-------------------|----------------------|------------|-----------------------------------|
| Final             | `v<x.y.z>`           | `main`     | A stable version.                 |
| Release candidate | `v<x.y.z>-rc.<n>`    | `main`     | Meant to become `v<x.y.z>`.       |
| Dev               | `v<base>+<name>.<n>` | Any branch | None: its changes may never ship. |

### Release Steps

These steps apply to every kind of release.

1. Bump `version` in `rust/Cargo.toml` and `rust/Cargo.lock`.
   For a final release or a release candidate, do it in a PR to `main`.
   For a final release, also move `[Unreleased]` in `CHANGELOG.md` to a new version section, following
   [Keep a Changelog](https://keepachangelog.com/en/1.1.0/#effort).
2. Tag the last commit of the branch you release from, and push the tag. E.g., for `main`:

   ```bash
   git fetch origin
   git tag v0.8.0 origin/main
   git push origin v0.8.0
   ```

3. CI checks that the tag matches `rust/Cargo.toml`, builds and tests every platform, then creates a draft release
   with the bundles.

   > [!NOTE]
   > Release candidates and dev releases are marked as pre-releases.

4. CI commits the bundle hashes in `circuits_nix_hashes.json` to the tag's branch, then moves the tag onto that commit.
   The flake reads this file to download the release.
   Don't edit it by hand.

   > [!NOTE]
   > This fails if the branch got new commits after the tag. Then tag the new last commit with the next version,
   > e.g. `-rc.2` or `+<name>.2`.

5. Review the draft and publish it.
   The release notes are the tag's `CHANGELOG.md` section.
   Release candidates and dev releases use `[Unreleased]`.
   Dev releases also start with a note that names their branch and its PR.
   GitHub then adds "What's Changed", the list of PRs merged since the previous release.

### Dev (Branch) Releases

Use a dev release when you need a release without merging into `main`.
For example, an integration branch.

Dev releases are meant for testing.
Once the changes are validated, merge the branch into `main`.
Before you merge it, it must meet the same standards as any other PR.

#### Dev Tag Format

A dev tag is its base tag plus `+<name>.<n>`, e.g. `v0.1.2+putxos.1` or `v0.1.2-rc.2+putxos.1`.

- `<base>`: the release the branch is built on. It can be any release, but it is usually the latest one on `main`.
- `<name>`: a short name for the branch, in lowercase letters, digits and `-`.
- `<n>`: starts at 1 for each base, and goes up by 1 for each dev release on that base.

> [!NOTE]
> Only tag `v<x.y.z>` or `v<x.y.z>-rc.<n>` on `main`.
> CI rejects them anywhere else.

#### Syncing With `main`

When you sync (merge or rebase) with `main`:

- `rust/Cargo.toml`: update the dev version to use `main`'s version as its base, and restart `<n>` at 1.
  E.g., if `main` is at `0.8.0-rc.3`, `0.8.0-rc.2+putxos.3` becomes `0.8.0-rc.3+putxos.1`.
- `circuits_nix_hashes.json`: keep the entries from both sides.

#### Merging

1. Sync the branch with `main`, as in [Syncing With `main`](#syncing-with-main).
2. Remove the `+<name>.<n>` part from `version` in `rust/Cargo.toml`, e.g. `0.8.0-rc.3+putxos.1` to `0.8.0-rc.3`.
   Merging doesn't release the changes. To release them, follow [Release Steps](#release-steps) on `main`.
3. Squash-merge the PR.
   Don't delete dev tags or their releases, since consumers might still depend on them.
4. Update consumers if necessary.

### Release Bundles

For each supported platform (Linux x86_64, Linux aarch64, macOS aarch64, Windows x86_64), a release artifact is
generated:

**`logos-blockchain-circuits-{version}-{os}-{arch}.tar.gz`** — a complete bundle containing all components needed to
generate and verify proofs for all circuits.

**Bundle Structure:**

```text
logos-blockchain-circuits-{version}-{os}-{arch}/
├── lib/
│   ├── libgmp.a
│   └── libmman.a           (Windows only)
├── {circuit}/              (pol/, poq/, transfer/)
│   ├── include/
│   ├── lib{circuit}.a
│   ├── proving_key.zkey
│   ├── verification_key.json
│   └── witness_generator.dat
├── prover[.exe]
├── verifier[.exe]
└── VERSION
```

The proving keys are generated using the Hermez Powers of Tau ceremony — see [docs/build-pipeline.md § Step 2](docs/build-pipeline.md#step-2--proving-key-generation).
