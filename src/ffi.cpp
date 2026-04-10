#include "ffi.hpp"

#include <string>
#include <vector>
#include <algorithm>
#include <cstdlib>

#include <nlohmann/json.hpp>

#include "calcwit.hpp"
#include "circom.hpp"
#include "fr.hpp"

using json = nlohmann::json;

// ---- Forward declarations from circom-generated main.cpp ----

bool check_valid_number(std::string& s, uint base);
void json2FrElements(json val, std::vector<FrElement>& vval);
json::value_t check_type(std::string prefix, json in);
void qualify_input(std::string prefix, json& in, json& in1);
void qualify_input_list(std::string prefix, json& in, json& in1);

// -------------------------------------------------------------

// ---- File-based entry point (wraps circom-generated main) ----

static status::Status validate_generate_witness_from_files_input(const char* dat, const char* inputs, const char* output) {
    if (dat == nullptr) {
        return status::Status{status::StatusCode::InvalidInput, "dat is null"};
    }
    if (inputs == nullptr) {
        return status::Status{status::StatusCode::InvalidInput, "inputs is null"};
    }
    if (output == nullptr) {
        return status::Status{status::StatusCode::InvalidInput, "output is null"};
    }
    return status::ok();
}

extern "C" status::Status generate_witness_from_files(const char* dat, const char* inputs, const char* output) {
    const status::Status status = validate_generate_witness_from_files_input(dat, inputs, output);
    if (is_error(status)) {
        return status;
    }

    char* argv[] = {
        const_cast<char*>(dat),
        const_cast<char*>(inputs),
        const_cast<char*>(output),
        nullptr
    };
    const int code = main(3, argv);

    if (code == 0) {
        return status::ok();
    }
    return status::from_code(status::StatusCode::DynError);
}

// ---- Memory-based entry point ----

static status::Status validate_witness_input(const WitnessInput* input, const Bytes* output) {
    if (output == nullptr) {
        return status::Status{status::StatusCode::InvalidInput, "output is null"};
    }
    if (output->data != nullptr) {
        return status::Status{status::StatusCode::InvalidInput, "output.data is not null"};
    }

    if (input == nullptr) {
        return status::Status{status::StatusCode::InvalidInput, "input is null"};
    }
    if (input->dat.data == nullptr) {
        return status::Status{status::StatusCode::InvalidInput, "input.dat.data is null"};
    }
    if (input->dat.size == 0) {
        return status::Status{status::StatusCode::InvalidInput, "input.dat.size is zero"};
    }
    if (input->inputs_json == nullptr) {
        return status::Status{status::StatusCode::InvalidInput, "input.inputs_json is null"};
    }
    return status::ok();
}

extern "C" status::Status generate_witness(const WitnessInput* input, Bytes* output) {
    const status::Status status = validate_witness_input(input, output);
    if (is_error(status)) {
        return status;
    }

    // TODO: Implement the actual witness generation logic using the provided input data.
    const uint8_t dummy_witness[] = {0, 1, 2, 3}; // Placeholder for actual witness data

    const size_t witness_size = sizeof(dummy_witness);
    uint8_t* witness_data = static_cast<uint8_t*>(malloc(witness_size));
    if (witness_data == nullptr) {
        return status::Status{status::StatusCode::OutOfMemory, "Failed to allocate witness memory"};
    }
    std::copy(dummy_witness, dummy_witness + witness_size, witness_data);

    output->data = witness_data;
    output->size = witness_size;

    return status::ok();
}
