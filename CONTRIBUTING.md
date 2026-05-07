# Contributor's Guide

## Development Setup

### Prerequisites

- [Rust](https://rustup.rs/) — the pinned toolchain version is in `rust-toolchain.toml` and will be installed automatically by `rustup`.
- [pre-commit](https://pre-commit.com/) — used to run formatting, linting, and audit checks before each commit.

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
├── zksign/
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

