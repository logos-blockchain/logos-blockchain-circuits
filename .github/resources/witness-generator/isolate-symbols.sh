#!/bin/sh
# Isolates a circuit library's internal symbols on Windows, so several circuit libraries can link into 1 binary.
# See CONTRIBUTING.md § "Symbol Isolation".
#
# On Linux and macOS, the Makefile merges the objects with `ld -r`, then makes the internal symbols local.
# This does not work on Windows: it also makes COMDAT symbols local, e.g. template instances, so the link with
# libstdc++ fails.
# Thus, this script renames each internal symbol to `__<project>_priv_<symbol>` instead. It keeps the public FFI symbols
# and the COMDAT symbols.
#
# Usage: isolate-symbols.sh <project> <object>...
# Uses $NM, $OBJDUMP and $OBJCOPY, or the unprefixed tools.
set -eu
export LC_ALL=C

NM="${NM:-nm}"
OBJDUMP="${OBJDUMP:-objdump}"
OBJCOPY="${OBJCOPY:-objcopy}"

# Prints the global symbols that the objects define.
defined_symbols() {
  for object in "$@"; do
    "$NM" --extern-only --defined-only "$object" | awk '{ print $3 }'
  done | sort -u
}

# Prints the COMDAT symbols. Their sections are named `.<section>$<symbol>`.
comdat_symbols() {
  for object in "$@"; do
    "$OBJDUMP" -h "$object" | awk '{ print $2 }' | sed -n 's/^\.[a-z]*\$//p'
  done | sort -u
}

public_symbols() {
  project="$1"
  printf '%s\n' "${project}_generate_witness" "${project}_generate_witness_from_files"
}

# Prints `<old> <new>` for each internal symbol.
renames() {
  project="$1"
  awk -v p="$project" '
    /^\.refptr\./ { print $1 " .refptr.__" p "_priv_" substr($1, 9); next }
    { print $1 " __" p "_priv_" $1 }
  '
}

# Prints `<old> <new>` for the `.rdata$.refptr.<symbol>` section symbols. The linker merges these sections by name,
# so the sections and their symbols need new names too.
refptr_sections() {
  awk '/^\.refptr\./ { print ".rdata$" $1 " .rdata$" $2 }'
}

main() {
  project="$1"
  shift

  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT

  defined_symbols "$@" > "$work/defined"
  { comdat_symbols "$@"; public_symbols "$project"; } | sort -u > "$work/keep"
  comm -23 "$work/defined" "$work/keep" > "$work/internal"
  # MinGW adds a COMDAT `.refptr.<symbol>` for each <symbol> that it accesses by pointer. Rename it with its symbol.
  sed 's/^/.refptr./' "$work/internal" | comm -12 - "$work/defined" > "$work/refptrs"

  cat "$work/internal" "$work/refptrs" | renames "$project" > "$work/renames"
  refptr_sections < "$work/renames" > "$work/sections"
  cat "$work/sections" >> "$work/renames"

  for object in "$@"; do
    # shellcheck disable=SC2046 # One argument per line.
    "$OBJCOPY" --redefine-syms="$work/renames" \
      $(awk '{ print "--rename-section " $1 "=" $2 }' "$work/sections") "$object"
  done
}

main "$@"
