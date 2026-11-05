#!/usr/bin/env bash
# Runs rustfmt with the nightly toolchain pinned in [fmt] of rust-toolchain.toml. Extra args go to cargo fmt.
# Pass --install to only install the toolchain.
set -euo pipefail

toolchain=$(python3 -c 'import tomllib; print(tomllib.load(open("rust-toolchain.toml", "rb"))["fmt"]["toolchain"])')
install_cmd=(rustup toolchain install "$toolchain" --profile minimal --component rustfmt --no-self-update)

if [[ "${1:-}" == "--install" ]]; then
  exec "${install_cmd[@]}"
fi

if ! rustup run "$toolchain" rustfmt --version >/dev/null 2>&1; then
  echo "$toolchain with rustfmt required. Install it with:" >&2
  echo "  ./hooks/fmt.sh --install" >&2
  exit 1
fi

exec cargo +"$toolchain" fmt --manifest-path rust/Cargo.toml --all "$@"
