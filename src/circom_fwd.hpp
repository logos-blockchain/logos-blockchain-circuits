#ifndef CIRCOM_FWD_HPP
#define CIRCOM_FWD_HPP

/// Forward declarations for symbols defined in circom-generated main.cpp.
///
/// Circom compiles each circuit into a self-contained main.cpp that defines the witness generation
/// logic alongside several helper functions.
/// This header exposes those symbols so that FFI code can call into them without pulling in the full circom source.

#include <string>
#include <vector>

#include <nlohmann/json.hpp>

#include "calcwit.hpp"
#include "circom.hpp"
#include "fr.hpp"

using json = nlohmann::json;

/// Forward declaration of circom main(). Renamed via -Dmain=circom_main to avoid UB.
/// TODO: Successful path has no explicit return.
int circom_main(int argc, char* argv[]);
bool check_valid_number(std::string& s, uint base);
void json2FrElements(json val, std::vector<FrElement>& vval);
json::value_t check_type(std::string prefix, json in);
void qualify_input(std::string prefix, json& in, json& in1);
void qualify_input_list(std::string prefix, json& in, json& in1);

#endif
