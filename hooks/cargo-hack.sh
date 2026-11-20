#!/usr/bin/env bash
# Checks that each crate compiles with every combination of its features. Extra args go to cargo hack.
# Pass --install to only install the pinned cargo-hack version.
set -euo pipefail

VERSION="0.6.36"
install_cmd=(cargo install cargo-hack --locked --version "$VERSION")

if [[ "${1:-}" == "--install" ]]; then
  exec "${install_cmd[@]}"
fi

current="$(cargo hack --version 2>/dev/null || echo "none")"

if [[ "$current" != "cargo-hack $VERSION" ]]; then
  echo "cargo-hack $VERSION required (found: $current). Install it with:" >&2
  echo "  ./hooks/cargo-hack.sh --install" >&2
  exit 1
fi

# `prebuilt` is always on, so the build scripts can download the bundle when `LBC_ROOT_DIR` isn't set.
# `--no-dev-deps` stops dev-dependencies from enabling features, e.g. the tests crate enables `test-inputs`.
export RUSTFLAGS="-D warnings"
exec cargo hack check \
  --manifest-path rust/Cargo.toml \
  --workspace \
  --feature-powerset \
  --features prebuilt \
  --ignore-unknown-features \
  --no-dev-deps \
  --keep-going \
  "$@"
