#include "pol/ffi.hpp"
#include "circom_fwd.hpp"
#include "circom_adapter.hpp"

#include <string>
#include <algorithm>

#include "../types.hpp"

template<typename T>
static Status exceptions_into_status(T&& func) {
    try {
        return func();
    } catch (const std::bad_alloc&) {
        return status_from_code(StatusCode_OutOfMemory);
    } catch (const std::exception& e) {
        return status_new(StatusCode_DynError, e.what());
    } catch (...) {
        return status_new(StatusCode_DynError, "An unknown error occurred.");
    }
}

static Status validate_generate_witness_from_files_arguments(const char* dat, const char* inputs, const char* output) {
    if (dat == nullptr) {
        return status_new(StatusCode_InvalidInput, "dat is null.");
    }
    if (inputs == nullptr) {
        return status_new(StatusCode_InvalidInput, "inputs is null.");
    }
    if (output == nullptr) {
        return status_new(StatusCode_InvalidInput, "output is null.");
    }
    return status_ok();
}

static Status generate_witness_from_files_impl(const char* dat, const char* inputs, const char* output) {
    char* argv[] = {
        const_cast<char*>(dat),
        const_cast<char*>(inputs),
        const_cast<char*>(output),
        nullptr
    };

    const int code = circom_main(3, argv);
    if (code == 0) {
        return status_ok();
    }
    const std::string message = "Witness generation [circom main()] failed with code: " + std::to_string(code) + ".";
    return status_new(StatusCode_DynError, message.c_str());
}

extern "C" Status pol_generate_witness_from_files(const char* dat, const char* inputs, const char* output) {
    const Status status = validate_generate_witness_from_files_arguments(dat, inputs, output); // NOLINT: if-init
    if (status_is_error(status)) {
        return status;
    }

    return exceptions_into_status([&] {
        return generate_witness_from_files_impl(dat, inputs, output);
    });
}

// ---- Memory-based entry point ----

static Status validate_witness_arguments(const WitnessInput* input, const Bytes* output) {
    if (input == nullptr) {
        return status_new(StatusCode_InvalidInput, "input is null.");
    }
    if (input->dat.data == nullptr) {
        return status_new(StatusCode_InvalidInput, "input.dat.data is null.");
    }
    if (input->dat.size == 0) {
        return status_new(StatusCode_InvalidInput, "input.dat.size is zero.");
    }
    if (input->inputs_json == nullptr) {
        return status_new(StatusCode_InvalidInput, "input.inputs_json is null.");
    }

    if (output == nullptr) {
        return status_new(StatusCode_InvalidInput, "output is null.");
    }
    if (output->data != nullptr) {
        return status_new(StatusCode_InvalidInput, "output.data is not null.");
    }

    return status_ok();
}

static Status generate_witness_impl(const WitnessInput* input, Bytes* output) {
    const ConstBytes& circuit_bytes = input->dat;

    Circom_Circuit* circuit = loadCircuit(circuit_bytes);
    Circom_CalcWit* ctx = new Circom_CalcWit(circuit);

    loadJson(ctx, input->inputs_json);
    if (ctx->getRemaingInputsToBeSet()!=0) {
        const std::string message = "Not all inputs have been set. Only " + std::to_string(get_main_input_signal_no()-ctx->getRemaingInputsToBeSet()) + " out of " + std::to_string(get_main_input_signal_no()) + ".";
        delete ctx;
        delete circuit;
        return status_new(StatusCode_InvalidInput, message.c_str());
    }

    writeBinWitness(ctx, output);
    delete ctx;
    delete circuit;

    return status_ok();
}

extern "C" Status pol_generate_witness(const WitnessInput* input, Bytes* output) {
    const Status status = validate_witness_arguments(input, output); // NOLINT: if-init
    if (status_is_error(status)) {
        return status;
    }

    return exceptions_into_status([&] {
        return generate_witness_impl(input, output);
    });
}
