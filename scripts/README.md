# Scripts Directory

This directory contains build scripts for compiling the Logos Blockchain Circuits.

## Files

### [`build-local.sh`](build-local.sh)

The main local build script that replicates the GitHub Actions workflow for local execution on Linux. It handles the complete build pipeline including:

- Installing system dependencies (build-essential, cmake, libgmp-dev, etc.)
- Installing Rust and Circom compiler
- Installing Node.js and snarkjs
- Downloading Powers of Tau file (~3GB)
- Generating proving keys for all circuits (pol, poq, zksign, poc)
- Compiling witness generators
- Building prover and verifier from rapidsnark
- Creating the final release bundle

**Usage:**
```bash
./build-local.sh [OPTIONS]
```

**Options:**
| Option | Description |
|--------|-------------|
| `--version VERSION` | Set the version (default: v0.0.0-local) |
| `--skip-deps` | Skip installing system dependencies |
| `--skip-circom` | Skip Circom installation |
| `--skip-snarkjs` | Skip snarkjs installation |
| `--skip-ptau` | Skip Powers of Tau download |
| `--skip-proving-keys` | Skip proving key generation |
| `--skip-prover` | Skip prover/verifier compilation |
| `--skip-witness` | Skip witness generator compilation |
| `--circuit CIRCUIT` | Build only specified circuit (pol, poq, zksign, poc) |
| `--clean` | Clean all build artifacts before building |
| `--help` | Show help message |

### [`docker-build.sh`](docker-build.sh)

A wrapper script that runs the build inside a Docker container to avoid polluting your host system with dependencies.

**Usage:**
```bash
./docker-build.sh [OPTIONS]
```

All options are passed directly to `build-local.sh` inside the container.

**Examples:**
```bash
./docker-build.sh                    # Full build
./docker-build.sh --help             # Show build-local.sh help
./docker-build.sh --circuit pol      # Build only PoL circuit
./docker-build.sh --clean            # Clean and rebuild
./docker-build.sh --skip-ptau        # Skip Powers of Tau download
```

**Environment Variables:**
| Variable | Description |
|----------|-------------|
| `DOCKER_BUILD=0` | Skip rebuilding the Docker image |
| `DOCKER_NOCACHE=1` | Force rebuild Docker image without cache |
| `SKIP_INSTALL=true` | Install artifacts to `~/.nomos-circuits` after build |

### [`Dockerfile`](Dockerfile)

Defines the Docker build environment based on Ubuntu 22.04 with all required dependencies pre-installed:

- Build tools (gcc, cmake, make, nasm)
- Libraries (libgmp, libsodium, nlohmann-json)
- Node.js 20.x and snarkjs
- Rust and Circom compiler

The container automatically initializes git submodules and runs the build with `--skip-deps --skip-circom --skip-snarkjs` since these are pre-installed.

## Output

The build produces a tarball named `nomos-circuits-{VERSION}-{OS}-{ARCH}.tar.gz` containing:

```
nomos-circuits-v0.0.0-local-linux-x86_64/
├── VERSION
├── prover              # Rapidsnark prover binary
├── verifier            # Rapidsnark verifier binary
├── pol/
│   ├── witness_generator
│   ├── witness_generator.dat
│   ├── proving_key.zkey
│   └── verification_key.json
├── poq/
│   └── ...
├── zksign/
│   └── ...
└── poc/
    └── ...
```

## Requirements

- **Local build:** Linux x86_64 or aarch64, root access for dependencies
- **Docker build:** Docker installed and running
