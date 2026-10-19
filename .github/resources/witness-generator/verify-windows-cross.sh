#!/bin/sh
# Gate for the windows-x86_64-gnu bundle: every archive is PE, exports exactly
# its two entry points, and leaks no internal globals. Run inside the pinned
# toolchain:  nix develop .#windows-cross -c sh <this> <bundle-dir>
set -eu
BUNDLE="$1"
for c in pol poq signature poc; do
  lib="$BUNDLE/$c/lib${c}.a"
  fmt=$(x86_64-w64-mingw32-objdump -f "$lib" | grep -m1 'file format')
  echo "$c -> $fmt"
  echo "$fmt" | grep -q pe-x86-64 || { echo "::error::$c is not PE x86-64"; exit 1; }
  n=$(x86_64-w64-mingw32-nm --extern-only --defined-only "$lib" | grep -cE " T ${c}_generate_witness")
  [ "$n" -eq 2 ] || { echo "::error::$c exports $n entry points, expected 2"; exit 1; }
  leak=$(x86_64-w64-mingw32-nm --extern-only --defined-only "$lib" | grep -cE " T (Fr_|Circom)" || true)
  [ "$leak" -eq 0 ] || { echo "::error::$c leaks $leak internal globals"; exit 1; }
done
echo "toolchain: $(cat "$BUNDLE/TOOLCHAIN")"
