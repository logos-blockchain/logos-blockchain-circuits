#!/usr/bin/env bash
# Runs rustfmt with the nightly toolchain pinned in [fmt] of rust-toolchain.toml. Extra args go to cargo fmt.
set -euo pipefail

toolchain=$(python3 -c 'import tomllib; print(tomllib.load(open("rust-toolchain.toml", "rb"))["fmt"]["toolchain"])')
rustup toolchain install "$toolchain" --profile minimal --component rustfmt --no-self-update
cargo +"$toolchain" fmt --manifest-path rust/Cargo.toml --all "$@"
