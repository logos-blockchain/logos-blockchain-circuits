#!/bin/sh
# Hide a circuit's internal symbols so several circuit libraries can be linked
# into one binary, without the `ld -r` + --keep-global-symbol pass the native
# targets use.
#
# Why a second mechanism: on PE/COFF that pass produces an archive that cannot
# be linked by an external toolchain. `ld -r` merging the COMDAT sections GCC
# emits for templates yields `relocation truncated to fit: IMAGE_REL_AMD64_REL32`
# on the merged object, and --keep-global-symbol then localizes those same
# COMDAT symbols (std::__cxx11::to_string, nlohmann/json instantiations), so the
# consumer's own copies no longer satisfy them. Localizing per object instead
# breaks references *between* the objects.
#
# Renaming has none of those problems: every internal global gets a per-circuit
# prefix, applied identically to every object, so intra-archive references still
# resolve while nothing collides across circuits. COMDAT symbols are left alone
# precisely because they are meant to be shared.
#
# Usage: isolate-symbols.sh <project> <nm> <objdump> <objcopy> <obj>...
set -eu
export LC_ALL=C

PROJECT="$1"; NM="$2"; OBJDUMP="$3"; OBJCOPY="$4"; shift 4
[ $# -gt 0 ] || { echo "no objects given" >&2; exit 1; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

: > "$WORK/defined"
: > "$WORK/comdat"
for o in "$@"; do
    "$NM" --extern-only --defined-only "$o" | awk '{print $3}' >> "$WORK/defined"
    # COMDAT sections are named .text$<mangled>; that suffix is the symbol.
    "$OBJDUMP" -t "$o" | grep -oE '\.text\$[A-Za-z0-9_]+$' | sed 's/^\.text\$//' >> "$WORK/comdat"
done
sort -u "$WORK/defined" -o "$WORK/defined"
sort -u "$WORK/comdat"  -o "$WORK/comdat"

printf '%s_generate_witness\n%s_generate_witness_from_files\n' "$PROJECT" "$PROJECT" \
    | sort -u > "$WORK/public"
sort -u "$WORK/comdat" "$WORK/public" > "$WORK/keep"

comm -23 "$WORK/defined" "$WORK/keep" \
    | awk -v p="$PROJECT" '{print $1 " __" p "_priv_" $1}' > "$WORK/map"

echo "isolate-symbols: renaming $(wc -l < "$WORK/map") internal symbols, keeping $(wc -l < "$WORK/keep") (public + COMDAT)"
[ -s "$WORK/map" ] || exit 0
for o in "$@"; do
    "$OBJCOPY" --redefine-syms="$WORK/map" "$o"
done
