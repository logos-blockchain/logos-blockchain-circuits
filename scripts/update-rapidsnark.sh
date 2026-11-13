#!/usr/bin/env bash
# Pins a Logos Rapidsnark release in deps/rapidsnark/. See CONTRIBUTING.md § Rapidsnark.
set -euo pipefail

readonly REPO="logos-blockchain/logos-blockchain-rapidsnark"
DEPS="$(dirname "$0")/../deps/rapidsnark"
readonly DEPS
readonly VERSION_FILE="$DEPS/VERSION"
readonly SUMS_FILE="$DEPS/SHA256SUMS"

# Prints "<hash>  <archive>" for each archive of the release.
fetch_release_sums() {
  local tag="$1"
  gh release view "$tag" --repo "$REPO" --json assets \
    --jq '.assets[] | select(.name | endswith(".tar.gz")) | "\(.digest[7:])  \(.name)"'
}

# Prints the hash pinned in SHA256SUMS for the archive, or nothing.
pinned_hash() {
  local archive="$1"
  awk -v f="$archive" '$2 == f { print $1 }' "$SUMS_FILE"
}

# Prints the archives of the release that are missing or different in SHA256SUMS.
diff_sums() {
  local release_sums="$1"
  local hash archive pinned
  while read -r hash archive; do
    pinned=$(pinned_hash "$archive")
    if [ -z "$pinned" ]; then
      echo "  missing:   $archive"
    elif [ "$pinned" != "$hash" ]; then
      echo "  different: $archive"
      echo "    SHA256SUMS: $pinned"
      echo "    release:    $hash"
    fi
  done <<< "$release_sums"
}

report_version() {
  local current="$1" tag="$2"
  if [ "$current" = "$tag" ]; then
    echo "VERSION is already $tag."
  else
    echo "VERSION: $current -> $tag"
  fi
}

report_sums() {
  local tag="$1" diff="$2"
  if [ -z "$diff" ]; then
    echo "SHA256SUMS already has the hashes of $tag."
  else
    echo "SHA256SUMS differs from release $tag:"
    echo "$diff"
  fi
}

confirm() {
  local answer
  read -r -p "Apply? [y/N] " answer
  [ "$answer" = "y" ]
}

main() {
  if [ $# -ne 1 ]; then
    echo "usage: $0 <tag>"
    exit 1
  fi

  local tag="$1"
  local release_sums current diff

  release_sums=$(fetch_release_sums "$tag")
  if [ -z "$release_sums" ]; then
    echo "No archives in release $tag."
    exit 1
  fi

  current=$(cat "$VERSION_FILE")
  diff=$(diff_sums "$release_sums")

  report_version "$current" "$tag"
  report_sums "$tag" "$diff"

  if [ "$current" = "$tag" ] && [ -z "$diff" ]; then
    echo "Nothing to do."
    exit 0
  fi

  if ! confirm; then
    echo "Nothing changed."
    exit 1
  fi

  echo "$release_sums" > "$SUMS_FILE"
  echo "$tag" > "$VERSION_FILE"
  echo "Updated VERSION and SHA256SUMS."
}

main "$@"
