#ifndef CIRCOM_ADAPTER_HPP
#define CIRCOM_ADAPTER_HPP

#include "types.hpp"
#include "calcwit.hpp"
#include "circom.hpp"

// Return value
Circom_Circuit* loadCircuit(const ConstBytes& circuit);

// Returns a process-wide, lazily-loaded circuit for this library.
//
// `loadCircuit` allocates the circuit's internal buffers (input hash map,
// witness->signal list, constants, IO field defs) but `Circom_Circuit` has no
// destructor, so `delete circuit` leaks all of them. The circuit is immutable
// data derived from the compiled-in `.dat`, so we load it exactly once and
// reuse it for every (including concurrent) witness-generation call.
Circom_Circuit* getCachedCircuit(const ConstBytes& circuit);

void loadJson(Circom_CalcWit *ctx, const char* inputs_json);
void writeBinWitness(Circom_CalcWit *ctx, Bytes* output_witness);

#endif
