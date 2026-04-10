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
template<typename T>
static Status exceptions_into_status(T&& func) {
    try {
        return func();
    } catch (const std::bad_alloc&) {
        return status_from_code(StatusCode_OutOfMemory);
    } catch (const std::exception& e) {
        return Status{StatusCode_DynError, e.what()};
    } catch (...) {
        return Status{StatusCode_DynError, "An unknown error occurred."};
    }
}

static Status validate_generate_witness_from_files_input(const char* dat, const char* inputs, const char* output) {
    if (dat == nullptr) {
        return Status{StatusCode_InvalidInput, "dat is null"};
    }
    if (inputs == nullptr) {
        return Status{StatusCode_InvalidInput, "inputs is null"};
    }
    if (output == nullptr) {
        return Status{StatusCode_InvalidInput, "output is null"};
    }
    return status_ok();
}

static Status generate_witness_from_files_impl(const char* dat, const char* inputs, const char* output) {
    char* argv[] = {
        const_cast<char*>("generate_witness_from_files"),
        const_cast<char*>(dat),
        const_cast<char*>(inputs),
        const_cast<char*>(output),
        nullptr
    };

    const int code = main(4, argv);
    if (code == 0) {
        return status_ok();
    }
    return status_from_code(StatusCode_DynError);
}

extern "C" Status generate_witness_from_files(const char* dat, const char* inputs, const char* output) {
    const Status status = validate_generate_witness_from_files_input(dat, inputs, output);
    if (status_is_error(status)) {
        return status;
    }

    return exceptions_into_status([&] {
        return generate_witness_from_files_impl(dat, inputs, output);
    });
}

// ---- Memory-based entry point ----

static Status validate_witness_input(const WitnessInput* input, const Bytes* output) {
    if (output == nullptr) {
        return Status{StatusCode_InvalidInput, "output is null"};
    }
    if (output->data != nullptr) {
        return Status{StatusCode_InvalidInput, "output.data is not null"};
    }

    if (input == nullptr) {
        return Status{StatusCode_InvalidInput, "input is null"};
    }
    if (input->dat.data == nullptr) {
        return Status{StatusCode_InvalidInput, "input.dat.data is null"};
    }
    if (input->dat.size == 0) {
        return Status{StatusCode_InvalidInput, "input.dat.size is zero"};
    }
    if (input->inputs_json == nullptr) {
        return Status{StatusCode_InvalidInput, "input.inputs_json is null"};
    }
    return status_ok();
}

static Status generate_witness_impl(const WitnessInput* input, Bytes* output) {
    // TODO: Implement the actual witness generation logic using the provided input data.
    const uint8_t dummy_witness[] = {0, 1, 2, 3}; // Placeholder for actual witness data

    const size_t witness_size = sizeof(dummy_witness);
    uint8_t* witness_data = static_cast<uint8_t*>(malloc(witness_size));
    if (witness_data == nullptr) {
        return Status{StatusCode_OutOfMemory, "Failed to allocate witness memory"};
    }
    std::copy(dummy_witness, dummy_witness + witness_size, witness_data);

    output->data = witness_data;
    output->size = witness_size;

    return status_ok();
}

extern "C" Status generate_witness(const WitnessInput* input, Bytes* output) {
    const Status status = validate_witness_input(input, output);
    if (status_is_error(status)) {
        return status;
    }

    return exceptions_into_status([&] {
        return generate_witness_impl(input, output);
    });
}

extern "C" void free_bytes(Bytes* bytes) {
    if (bytes == nullptr) {
        return;
    }

    free(bytes->data);
    bytes->data = nullptr;
    bytes->size = 0;
}
