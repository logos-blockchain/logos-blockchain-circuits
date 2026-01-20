# Contributor's Guide

## Triggering a New Release for Logos Blockchain Circuits

To trigger a release build:

1. Create and push a tag in the format `vX.Y.Z`.
2. This will automatically trigger the `.github/workflows/build_circuits.yml` workflow.
3. Once the workflow finishes, the generated artifacts will be attached to a new release.

> Currently, releases published this way are marked as **Draft** and **Pre-Release** to ensure that the changelog and pre-release steps are manually reviewed first.

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
│   ├── witness_generator[.exe]
│   ├── witness_generator.dat
│   ├── proving_key.zkey
│   └── verification_key.json
├── poq/
│   ├── witness_generator[.exe]
│   ├── witness_generator.dat
│   ├── proving_key.zkey
│   └── verification_key.json
├── zksign/
│   ├── witness_generator[.exe]
│   ├── witness_generator.dat
│   ├── proving_key.zkey
│   └── verification_key.json
└── poc/
    ├── witness_generator[.exe]
    ├── witness_generator.dat
    ├── proving_key.zkey
    └── verification_key.json
```

At the root level:
- **prover**: Rapidsnark prover binary for generating zk-SNARK proofs
- **verifier**: Rapidsnark verifier binary for verifying proofs

Each circuit directory contains:
- **witness_generator**: Compiled C++ binary for generating witnesses from inputs
- **witness_generator.dat**: Required data file for the witness generator
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

