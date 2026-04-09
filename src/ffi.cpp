#include "ffi.hpp"

#include <string>
#include <vector>

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

// ---- File-based entry point (wraps circom-generated main) ----

extern "C" int generate_witness_from_files(const char* dat, const char* inputs, const char* output) {
    char* argv[] = {
        (char*)dat,
        (char*)inputs,
        (char*)output,
        nullptr
    };
    return main(3, argv);
}

// ---- Memory-based entry point ----

extern "C" int generate_witness(const WitnessInput input, Bytes* output) {
    // TODO
    return 0;
}
