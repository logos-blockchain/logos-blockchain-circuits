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

Point the build script at any directory containing the compiled circuit libraries:

```bash
LBC_POQ_LIB_DIR=/path/to/poq
LBC_POL_LIB_DIR=/path/to/pol
LBC_POC_LIB_DIR=/path/to/poc
LBC_SIGNATURE_LIB_DIR=/path/to/signature
LBC_LIB_DIR=/path/to/lib                 # Directory containing the required libs
                                         # If using a release bundle, this is the included lib/ directory
```

> The `justfile` at the repo root contains recipes (`just poq`, `just pol`, etc.) that build the circuit libraries from
> source.
>
> This is not yet an officially supported workflow, but it can serve as a reference if you need to produce the
> libraries yourself.

## Usage

### In-memory witness generation

```rust
use lbc_poq_sys::native::{PoqWitnessInput, generate_witness};
use lbc_types::native::{Error, Witness};

fn main() -> Result<Witness, Error> {
    let inputs_json = std::fs::read_to_string("poq-input.json").expect("failed to read input");
    let input = PoqWitnessInput::new(inputs_json)?;
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
