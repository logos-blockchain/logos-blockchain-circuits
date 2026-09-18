#!/bin/sh
# Build the windows-x86_64-gnu circuit libraries. Run inside the pinned
# toolchain:  nix develop .#windows-cross -c sh <this> <out-dir> <circuit>...
# where each <circuit> is `path/to/name.circom`. circom must be on PATH.
set -eu
OUT="$1"; shift
ROOT=$(git rev-parse --show-toplevel)
RES="$ROOT/.github/resources/witness-generator"
: "${CROSS_GMP_LIB:?run inside: nix develop .#windows-cross}"

DEPS=$(mktemp -d); trap 'rm -rf "$DEPS"' EXIT
mkdir -p "$DEPS/include/nlohmann" "$DEPS/include/sys" "$DEPS/lib" "$OUT/lib"
curl -fsSL -o "$DEPS/include/nlohmann/json.hpp" \
  https://github.com/nlohmann/json/releases/download/v3.12.0/json.hpp

# The circuit objects call mmap/munmap. Built here, with the same toolchain as
# the archives, so it cannot drift from them the way a prebuilt shim would.
git clone -q --depth 1 https://github.com/alitrack/mman-win32.git "$DEPS/mman"
x86_64-w64-mingw32-gcc -c "$DEPS/mman/mman.c" -o "$DEPS/mman/mman.o" -I"$DEPS/mman"
x86_64-w64-mingw32-ar rcs "$OUT/lib/libmman.a" "$DEPS/mman/mman.o"
cp "$DEPS/mman/mman.h" "$DEPS/include/sys/mman.h"
cp "$CROSS_GMP_LIB/libgmp.a" "$OUT/lib/libgmp.a"

for circuit in "$@"; do
  project=$(basename "$circuit" .circom)
  dir="$ROOT/$(dirname "$circuit")"
  cpp="$dir/${project}_cpp"
  ( cd "$dir" && circom --c --r1cs --no_asm --O2 "$(basename "$circuit")" )
  cp -r "$ROOT/src/$project" "$cpp/$project"
  for f in circom_adapter.cpp circom_adapter.hpp circom_fwd.hpp types.hpp assert.h; do
    cp "$ROOT/src/$f" "$cpp/$f"
  done
  cp "$RES/Makefile" "$cpp/Makefile"
  # circom's main() has no return on the success path
  sed -i ':a;N;$!ba;s/\n}\n\n*$/\n  return 0;\n}/' "$cpp/main.cpp"
  sh "$RES/fix_calcwit_leak.sh" "$cpp"
  make -C "$cpp" PROJECT="$project" OS=windows-cross windows-cross-lib \
    CXX=x86_64-w64-mingw32-g++ AR=x86_64-w64-mingw32-ar \
    NM=x86_64-w64-mingw32-nm OBJDUMP=x86_64-w64-mingw32-objdump \
    OBJCOPY=x86_64-w64-mingw32-objcopy ISOLATE="$RES/isolate-symbols.sh" \
    PRIORITY_FLAGS="-I$CROSS_GMP_INCLUDE -I$DEPS/include $CROSS_EXTRA_INCLUDES"

  mkdir -p "$OUT/$project/include"
  cp "$cpp/lib${project}.a" "$OUT/$project/"
  cp "$cpp/${project}.dat" "$OUT/$project/witness_generator.dat"
  for h in calcwit.hpp circom.hpp fr.hpp types.hpp; do cp "$cpp/$h" "$OUT/$project/include/"; done
  cp "$cpp/$project/ffi.hpp" "$OUT/$project/include/"
done

echo "$TOOLCHAIN_ID" > "$OUT/TOOLCHAIN"
echo "built with: $TOOLCHAIN_ID"
