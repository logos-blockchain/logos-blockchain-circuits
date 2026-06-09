#!/bin/sh
# Patch the circom-generated `Circom_CalcWit` destructor to free the per-call
# allocations made in its constructor.
#
# circom's `--c` backend emits an EMPTY `~Circom_CalcWit()` destructor on
# purpose: the generated witness-generator *binary* computes a single witness
# and then exits, so the OS reclaims everything. We link the generated code as
# an in-process *library* and call it once per proof, so that empty destructor
# leaks the entire signal buffer (`signalValues`, ~total_signals * sizeof(Fr) =
# megabytes), plus `componentMemory` (and its per-component sub-buffers) and
# `inputSignalAssigned`, on EVERY call.
#
# This rewrites the destructor to free those allocations. The per-component
# frees mirror circom's own `release_memory_component` (guarded `if(ptr)
# delete[]`), so they are safe even if the generated run already released some
# components.
#
# Usage: fix_calcwit_leak.sh <dir-containing-generated-calcwit.cpp>
set -eu

DIR="${1:?usage: fix_calcwit_leak.sh <generated-cpp-dir>}"
CALCWIT="$DIR/calcwit.cpp"

[ -f "$CALCWIT" ] || { echo "fix_calcwit_leak: $CALCWIT not found" >&2; exit 1; }

if grep -q "logos: free per-call allocations" "$CALCWIT"; then
    echo "fix_calcwit_leak: $CALCWIT already patched, skipping"
    exit 0
fi

perl -0777 -i -pe '
    my $body = q{Circom_CalcWit::~Circom_CalcWit() {
  // logos: free per-call allocations. circom leaves this destructor empty
  // because the generated binary exits after one witness; we call the
  // generated code in-process as a library, so without these frees every
  // witness-generation call leaks signalValues (megabytes), componentMemory
  // and inputSignalAssigned. These three are allocated once in the constructor
  // and freed nowhere else. NOTE: the per-component sub-buffers
  // (subcomponents/outputIsSet/mutexes/...) are already released during the
  // witness computation by circoms own release_memory_component, so they must
  // NOT be freed here -- doing so double-frees.
  delete[] signalValues;
  delete[] inputSignalAssigned;
  delete[] componentMemory;
}};
    my $n = (s/Circom_CalcWit::~Circom_CalcWit\s*\(\s*\)\s*\{.*?\n\}/$body/s);
    die "fix_calcwit_leak: could not locate ~Circom_CalcWit() destructor\n" unless $n == 1;
' "$CALCWIT"

echo "fix_calcwit_leak: patched $CALCWIT"
