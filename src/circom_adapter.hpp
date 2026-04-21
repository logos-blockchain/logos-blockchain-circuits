#ifndef CIRCOM_ADAPTER_HPP
#define CIRCOM_ADAPTER_HPP

#include "types.hpp"
#include "calcwit.hpp"
#include "circom.hpp"

// Return value
Circom_Circuit* loadCircuit(const ConstBytes& circuit);
void loadJson(Circom_CalcWit *ctx, const char* inputs_json);
void writeBinWitness(Circom_CalcWit *ctx, Bytes* output_witness);

#endif
