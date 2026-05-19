# Contributor's Guide

## Development Setup

### Prerequisites

- [Rust](https://rustup.rs/) — the pinned toolchain version is in `rust-toolchain.toml` and will be installed automatically by `rustup`.
- [pre-commit](https://pre-commit.com/) — used to run formatting, linting, and audit checks before each commit.
- `llvm-objcopy` — required to build circuit static libraries (symbol isolation) on Linux. Install via `sudo apt install -y llvm`. On Windows (MSYS2), GNU `objcopy` from `mingw-w64-x86_64-toolchain` is used instead (no extra install needed). On macOS, symbol isolation is skipped entirely, so no objcopy tool is required.

### Installing the Pre-Commit Hooks

```bash
pre-commit install
```

This only needs to be done once after cloning the repo. Hooks will then run automatically on `git commit`.

### Running Checks Manually

To run all hooks manually against all files:

```bash
pre-commit run --all-files
```

### Maintenance

#### Rust Toolchain

When bumping the stable toolchain, update `channel` in `rust-toolchain.toml`. The comment there lists every other place that must be updated in sync (nightly version, CI workflows, pre-commit hooks).

#### Tool Versions

`taplo`, `cargo-deny`, and `cargo-machete` are pinned in two places that must stay in sync:
- `.pre-commit-config.yaml` (hook `rev`)
- `.github/workflows/lint.yml` (`cargo install --version`)

---

## Symbol Isolation in Circuit Libraries

Each circuit (PoQ, PoL, PoC, Signature) is compiled into a static archive (`libpoq.a`, `libpol.a`, etc.). 
All four archives share the same internal C++ runtime — `loadCircuit`, `get_size_of_witness`, the `fr_*` field 
arithmetic functions, `calcwit_*` functions, and others. They are compiled from the same source files but with 
**different constant values per circuit** (e.g. `get_size_of_witness()` returns 18149 for PoQ and 20531 for PoL).

### The Problem

When two or more circuit libraries are linked into the same binary, the GNU linker silently picks the first definition 
it encounters for each symbol and discards the rest. 
No error, no warning. 
The result is that one circuit's constants end up hardwired into functions shared by both circuits, corrupting witness 
parsing. 
In practice: the wrong `get_size_of_witness()` value causes `loadCircuit` to compute an incorrect buffer size, `pu32` 
walks off the end of the buffer, reads garbage as a length field, and the subsequent `memcpy` reads past the stack guard
page, which results in a **SIGSEGV**.

### The Fix

The Makefile's `$(LIB)` rule uses a two-step process on Linux and Windows to localize all circuit-specific code before
archiving:

1. **Partial link** (`ld -r`): merges all circuit-specific `.o` files — everything except `fr.o` (pure field
arithmetic, no circuit-specific calls) — into a single relocatable object. No symbols are resolved yet; this is
consolidation only.
2. **Symbol localization** (`llvm-objcopy --keep-global-symbol` on Linux, `objcopy --keep-global-symbol` on Windows): demotes every global symbol to local *except* the
circuit's two public FFI entry points (`$(PROJECT)_generate_witness` and `$(PROJECT)_generate_witness_from_files`).
Local symbols are invisible to the final linker, so each archive retains a private copy of every internal symbol — no
conflict is possible regardless of how many circuits are linked together.

`llvm-objcopy` is required rather than GNU `objcopy`. GNU `objcopy` only changes the binding of COMDAT signature
symbols to local, which confuses the linker's deduplication logic and causes "relocation refers to symbol in discarded
section" errors. `llvm-objcopy` additionally clears the `GRP_COMDAT` flag on affected section groups, turning them into
regular non-COMDAT sections that are simply kept as-is rather than deduplicated. The result is a slightly larger binary
(each circuit keeps its own copy of shared template instantiations), but no linker errors.

`fr.o` is excluded from the merge because it contains only field arithmetic (`Fr_*`) with no circuit-specific calls.
It is safe to deduplicate across circuits — the linker picks one copy, which is correct since the code is identical.

On macOS, localization is skipped. macOS uses a two-level namespace by default, meaning symbols are qualified by which
library they come from, so the conflict does not arise.

On Windows, GNU `objcopy` (from MinGW binutils) is used instead of `llvm-objcopy`. `llvm-objcopy --keep-global-symbol`
is not supported for COFF objects, but GNU `objcopy --keep-global-symbol` works correctly on COFF — it maps the local
binding to COFF storage class `C_STAT`. The ELF `GRP_COMDAT` problem that required `llvm-objcopy` on Linux does not
apply on Windows: COFF COMDAT is per-section rather than group-based, and the linker already deduplicates it
automatically.

### Maintenance

`PUBLIC_SYMS` is hardcoded to `$(PROJECT)_generate_witness` and `$(PROJECT)_generate_witness_from_files` in the
Makefile. If the public FFI API ever changes — entry points renamed or new ones added — update that variable,
otherwise the affected symbols will be localized and linking will fail.

---

## Triggering a New Release for Logos Blockchain Circuits

To trigger a release build:

1. Create and push a tag in the format `vX.Y.Z`.
2. This will automatically trigger the `.github/workflows/build_circuits.yml` workflow.
3. Once the workflow finishes, the generated artifacts will be attached to a new release.

> Currently, releases published this way are marked as **Draft** and **Pre-Release** to ensure that the changelog and 
> pre-release steps are manually reviewed first.

### Generated Artifacts

Each release includes a single unified bundle per platform:

#### Unified Release Bundles

For each supported platform (Linux x86_64, macOS aarch64, Windows x86_64):

- **`logos-blockchain-circuits-{version}-{os}-{arch}.tar.gz`**

  A complete bundle containing all components needed to generate and verify proofs for all circuits.

**Bundle Structure:**

```
logos-blockchain-circuits-{version}-{os}-{arch}/
├── VERSION
├── prover[.exe]
├── verifier[.exe]
├── pol/
│   ├── libpol.a
│   ├── witness_generator.dat
│   ├── include/
│   ├── proving_key.zkey
│   └── verification_key.json
├── poq/
│   ├── libpoq.a
│   ├── witness_generator.dat
│   ├── include/
│   ├── proving_key.zkey
│   └── verification_key.json
├── signature/
│   ├── libsignature.a
│   ├── witness_generator.dat
│   ├── include/
│   ├── proving_key.zkey
│   └── verification_key.json
└── poc/
    ├── libpoc.a
    ├── witness_generator.dat
    ├── include/
    ├── proving_key.zkey
    └── verification_key.json
```

> On Windows, static libraries use the `.lib` extension instead of `.a` (e.g. `pol.lib`).

At the root level:
- **prover**: Rapidsnark prover binary for generating zk-SNARK proofs
- **verifier**: Rapidsnark verifier binary for verifying proofs

Each circuit directory contains:
- **lib{circuit}.a / {circuit}.lib**: Static library for generating witnesses from inputs
- **witness_generator.dat**: Required data file for the witness generator
- **include/**: C headers for linking against the witness generator library
- **proving_key.zkey**: Groth16 proving key for generating zk-SNARK proofs
- **verification_key.json**: Verification key for verifying proofs

The proving keys are generated using the Hermez Powers of Tau ceremony (`powersOfTau28_hez_final_17.ptau`), which supports circuits with up to 2^17 constraints.

### Example

```bash
git tag v1.2.3 -m "Release v1.2.3"
git push --tags
```

## Publishing the Release

After triggering the release, it will appear as a **Draft** and **Pre-Release**.  
Before making it public, make sure to:

1. **Review the changelog**  
   Ensure that all relevant changes are clearly listed and properly formatted.

2. **Confirm the pre-release checklist**  
   Verify that all required steps have been completed, then remove the checklist from the release notes.

Once everything looks good:

3. **Mark the release as published**  
   - Uncheck **“This is a pre-release.”**  
   - Publish the release (removing the Draft state).

> ⚡ **Important:** Logos Blockchain builds will only pick up the new circuits once the release is published as **Latest** (i.e. not marked as draft or pre-release).

