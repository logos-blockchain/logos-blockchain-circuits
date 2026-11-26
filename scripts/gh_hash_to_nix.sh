#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <sha256-hex | sha256:hex | sha256-SRI>"
  exit 1
fi

input="$1"

# If already SRI, print as-is
if [[ "$input" =~ ^sha256- ]]; then
  echo "$input"
  exit 0
fi

# Strip optional sha256: prefix
hex="${input#sha256:}"

# Convert hex → SRI
nix hash convert --hash-algo sha256 "$hex"
