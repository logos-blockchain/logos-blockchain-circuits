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
  // witness-generation call leaks signalValues (megabytes) + componentMemory
  // + inputSignalAssigned. The per-component frees mirror circoms own
  // release_memory_component (guarded), so they are safe to run once here.
  for (int i = 0; i < get_number_of_components(); i++) {
    if (componentMemory[i].subcomponents) delete[] componentMemory[i].subcomponents;
    if (componentMemory[i].subcomponentsParallel) delete[] componentMemory[i].subcomponentsParallel;
    if (componentMemory[i].outputIsSet) delete[] componentMemory[i].outputIsSet;
    if (componentMemory[i].mutexes) delete[] componentMemory[i].mutexes;
    if (componentMemory[i].cvs) delete[] componentMemory[i].cvs;
    if (componentMemory[i].sbct) delete[] componentMemory[i].sbct;
  }
  delete[] componentMemory;
  delete[] signalValues;
  delete[] inputSignalAssigned;
}};
    my $n = (s/Circom_CalcWit::~Circom_CalcWit\s*\(\s*\)\s*\{.*?\n\}/$body/s);
    die "fix_calcwit_leak: could not locate ~Circom_CalcWit() destructor\n" unless $n == 1;
' "$CALCWIT"

echo "fix_calcwit_leak: patched $CALCWIT"
