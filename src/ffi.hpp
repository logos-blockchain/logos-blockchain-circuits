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
/// - `output`: Path to the output file where the witness will be written.
///
/// # Returns
///
/// On success, returns a `Status` with `StatusCode::Ok` and writes the witness to the specified output file.
/// On failure, returns a `Status` with an appropriate error code.
status::Status generate_witness_from_files(const char* dat, const char* inputs, const char* output);

/// Generates a witness from in-memory buffers.
///
/// # Parameters
///
/// - `input`: The `WitnessInput` struct containing the circuit information.
/// - `output`: Pointer to a `Bytes` struct that will be populated with the generated witness bytes.
///
/// # Returns
///
/// On success, returns a `Status` with `StatusCode::Ok` and populates `output` with the generated witness bytes. The
/// caller is responsible for freeing the memory allocated for `output.data`.
/// On failure, returns a `Status` with an appropriate error code, and `output` will not be modified.
status::Status generate_witness(const WitnessInput* input, Bytes* output);

#ifdef __cplusplus
}
#endif

#endif
