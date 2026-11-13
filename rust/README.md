# Logos Blockchain Circuits — Rust

Rust bindings for the Logos Blockchain Circuits.

Each circuit has a `-sys` crate that wraps the underlying C FFI with a safe Rust API.

## Crates

| Crate               | Description                                     |
|---------------------|-------------------------------------------------|
| `lbc-poq-sys`       | Witness generator for PoQ (Proof of Quota)      |
| `lbc-pol-sys`       | Witness generator for PoL (Proof of Leadership) |
| `lbc-poc-sys`       | Witness generator for PoC (Proof of Claim)      |
| `lbc-signature-sys` | Witness generator for Signature                 |
| `lbc-types`         | Shared types                                    |
| `lbc-build`         | Build helper                                    |

## Providing the circuit libraries

Each `-sys` crate needs the compiled circuit library directory for its circuit, containing `lib{circuit}.a` and `witness_generator.dat`.
There are two ways to provide it, detailed below.

### Option A — Prebuilt download

Enable the `prebuilt` Cargo feature.

The build script downloads the release bundle matching the crate version from GitHub Releases and caches it locally.

```toml
[dependencies]
lbc-poq-sys = { version = "0.5", features = ["prebuilt"] }
```

The cache location depends on the operating system:

- Linux: `~/.cache/logos/blockchain/`
- macOS: `~/Library/Caches/logos/blockchain/`
- Windows: `%LOCALAPPDATA%\logos\blockchain\`

The downloaded bundle version always matches `CARGO_PKG_VERSION`.

### Option B — Custom path

Set `LBC_ROOT_DIR` to the top-level directory of an extracted release bundle:

```bash
LBC_ROOT_DIR=/path/to/logos-blockchain-circuits-v<version>-<os>-<arch>
```

> The `justfile` at the repo root contains recipes (`just poq`, `just pol`, etc.) that build the circuit libraries from
> source.
>
> This is not yet an officially supported workflow, but it can serve as a reference if you need to produce the
> libraries yourself.

### Running on a different machine

The crates give access to the bundle in 2 ways.

#### Embedded data

It's copied into the program at build time, so it works on any machine:

- `artifacts::{PROVING_KEY, VERIFICATION_KEY, CIRCUIT}`, in each circuit's `-sys` crate.
  The `embedded` feature, on by default, enables them.
- The witness generator, through `generate_witness`.

#### Paths

They point to files in the bundle, so these files must exist when the program runs:

- `artifacts::{PROVING_KEY_PATH, VERIFICATION_KEY_PATH, CIRCUIT_PATH}`, in each circuit's `-sys` crate.
  The `paths` feature, off by default, enables them.
  To generate a witness, use `CircuitWitnessInput::new` with the bytes read from `CIRCUIT_PATH`.
- `prover()` and `verifier()`, in `logos-blockchain-circuits-rapidsnark-sys`. They return the paths to
  [Logos Rapidsnark](https://github.com/logos-blockchain/logos-blockchain-rapidsnark)'s executables.

The paths are resolved when the program runs:

- If `LBC_ROOT_DIR` is set, the paths point to that directory.
- If it is not set, the paths point to the bundle directory that the build used.
   > This second case works out-of-the-box only on the machine that built the program.
   > On any other machine, set `LBC_ROOT_DIR` to the extracted bundle's top-level directory.

## Usage

### In-memory witness generation

```rust
use lbc_poq_sys::native::{PoqWitnessInput, generate_witness};
use lbc_types::native::{Error, Witness};

fn main() -> Result<Witness, Error> {
    let inputs_json = std::fs::read_to_string("poq-input.json").expect("failed to read input");
    let input = PoqWitnessInput::embedded(inputs_json)?;
    generate_witness(&input)
}
```

### File-based witness generation

```rust
use lbc_poq_sys::native::generate_witness_from_files;
use lbc_types::native::Error;
use std::path::Path;

fn main() -> Result<(), Error> {
    generate_witness_from_files(
        Path::new("/path/to/witness_generator"),  // Extensionless .dat file
        Path::new("poq-input.json"),
        Path::new("output.wtns"),
    )?;
    Ok(())
}
```

The other circuits follow the same pattern under `lbc_pol_sys`, `lbc_poc_sys` and `lbc_signature_sys`.

## Running tests

```bash
cargo test
```

If the tests run on a different machine from the one that compiled them, set `LBC_ROOT_DIR` on that machine to the
top-level directory of an extracted release bundle.
