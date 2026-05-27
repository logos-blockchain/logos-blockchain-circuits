# Contributor's Guide

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
```

After this, they will be run automatically on every commit.

#### Running Manually

To run the checks manually against all files:

```bash
pre-commit run --all-files
```

### Maintenance

#### Rust Toolchain

When bumping the stable toolchain, update `channel` in `rust-toolchain.toml`.
The comment there lists every other place that must be updated in sync (nightly version, CI workflows, pre-commit hooks).

#### Tool Versions

`taplo`, `cargo-deny`, and `cargo-machete` are pinned in two places that must stay in sync:

- `.pre-commit-config.yaml` (hook `rev`)
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

The Makefile uses a two-step process to hide all circuit-specific symbols before archiving:

1. **Partial link** (`ld -r`): merges all circuit-specific `.o` files into a single relocatable
   object. `fr.o` is excluded — it contains only field arithmetic with no circuit-specific calls
   and is safe to deduplicate across circuits.
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

## Releasing

### Triggering a Release Build

To trigger a release build:

1. Create and push a tag in the format `vX.Y.Z`:

   ```bash
   git tag v1.2.3 -m "Release v1.2.3"
   git push --tags
   ```

2. This will automatically trigger the `.github/workflows/build_circuits.yml` workflow.
3. Once the workflow finishes, the generated artifacts will be attached to a new release.

> Pull Requests will also generate artifacts, which may be found on the job's page, but won't generate a new release.

#### Generated artifacts

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

### Publishing

Releases are marked as **Draft** and **Pre-Release** to ensure the changelog and pre-release steps are manually reviewed
before going public. Before publishing:

1. **Review the changelog**  
   Ensure that all relevant changes are clearly listed and properly formatted.

2. **Confirm the pre-release checklist**  
   Verify that all required steps have been completed, then remove the checklist from the release notes.
3. **Mark the release as published**  
   - Uncheck **“This is a pre-release.”**  
   - Publish the release (removing the Draft state).
