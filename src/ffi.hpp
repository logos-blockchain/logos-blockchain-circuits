#ifndef FFI_HPP
#define FFI_HPP

#include "types.hpp"

/// Inputs for witness generation.
struct WitnessInput {
    /// Contents of the circuit's .dat file.
    const ConstBytes dat;
    /// Null-terminated JSON string of circuit inputs.
    const char* inputs_json;
};

#ifdef __cplusplus
extern "C" {
#endif

/// Generates a witness by delegating to the circom-generated CLI entry point.
///
/// # Parameters
///
/// - `dat`: Path to the .dat file. Must be extensionless.
/// - `inputs`: Path to the inputs file for the circuit. Must be a JSON file.
/// - `output`: Path where the output witness file will be written.
int generate_witness_from_files(const char* dat, const char* inputs, const char* output);

/// Generates a witness from in-memory buffers.
///
/// # Parameters
///
/// - `input`: The `WitnessInput` struct containing the circuit information.
/// - `output`: On success, this will be populated with the generated witness bytes.
///  The caller is responsible for freeing this buffer.
int generate_witness(const WitnessInput input, Bytes* output);

#ifdef __cplusplus
}
#endif

#endif // FFI_HPP
