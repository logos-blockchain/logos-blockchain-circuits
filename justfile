src             := justfile_directory() + "/src"
ci_makefile     := justfile_directory() + "/.github/resources/witness-generator/Makefile"
circom_version  := "2.2.2" # This version must match the version used in the CI

os := `uname -s`
sed_i := if os == "Darwin" { "sed -i ''" } else { "sed -i" }

# Verify the installed circom matches the pinned version.
check-circom:
    @circom --version | grep -qF "{{circom_version}}" || \
        (echo "circom {{circom_version}} required; got: $(circom --version 2>&1)" >&2; exit 1)

prettify:
    nix shell nixpkgs#clang-tools -c clang-format -i src/**.cpp src/**.hpp

# Run a Sage script in a Docker container.
# Output is written relative to the script's directory.
# Example: just sage-run blend/generate_inputs_for_poq.py 1 10 5 0
#   -> blend/input.json
sage-run script +args='':
    docker run --rm \
        -v "{{justfile_directory()}}:/work" \
        -w "/work/$(dirname '{{script}}')" \
        sagemath/sagemath sage "$(basename '{{script}}')" {{args}}

# Build the PoQ circuit and its C++ witness generator, equivalent to the CI build.
poq: check-circom
    circom blend/poq.circom --c --r1cs --no_asm --O2 --output blend
    # circom-generated main() has no return on the success path; patch it before -O3 turns it into an infinite loop
    {{sed_i}} ':a;N;$!ba;s/\n}\n\n*$/\n  return 0;\n}/' blend/poq_cpp/main.cpp
    cp -r {{src}}/poq blend/poq_cpp/poq
    cp {{src}}/circom_adapter.cpp {{src}}/circom_adapter.hpp {{src}}/circom_fwd.hpp {{src}}/types.hpp blend/poq_cpp/
    cp {{ci_makefile}} blend/poq_cpp/Makefile
    cp blend/test_ffi.cpp blend/poq_cpp/test_ffi.cpp
    make -C blend/poq_cpp PROJECT=poq linux-lib

# Run a simple smoke test of the PoQ witness generator.
test-poq: poq
    g++ -std=c++11 -O3 -I blend/poq_cpp blend/poq_cpp/test_ffi.cpp -L blend/poq_cpp -lwitness_poq -lgmp -o blend/poq_cpp/test_ffi
    cd blend/poq_cpp && ./test_ffi

# Build the PoL circuit and its C++ witness generator, equivalent to the CI build.
pol: check-circom
    circom mantle/pol.circom --c --r1cs --no_asm --O2 --output mantle
    # circom-generated main() has no return on the success path; patch it before -O3 turns it into an infinite loop
    {{sed_i}} ':a;N;$!ba;s/\n}\n\n*$/\n  return 0;\n}/' mantle/pol_cpp/main.cpp
    cp -r {{src}}/pol mantle/pol_cpp/pol
    cp {{src}}/circom_adapter.cpp {{src}}/circom_adapter.hpp {{src}}/circom_fwd.hpp {{src}}/types.hpp mantle/pol_cpp/
    cp {{ci_makefile}} mantle/pol_cpp/Makefile
    cp mantle/test_pol.cpp mantle/pol_cpp/test_pol.cpp
    make -C mantle/pol_cpp PROJECT=pol linux-lib

# Run a simple smoke test of the PoL witness generator.
test-pol: pol
    g++ -std=c++11 -O3 -I mantle/pol_cpp mantle/pol_cpp/test_pol.cpp -L mantle/pol_cpp -lwitness_pol -lgmp -o mantle/pol_cpp/test_pol
    cd mantle/pol_cpp && ./test_pol

# Build the PoC circuit and its C++ witness generator, equivalent to the CI build.
poc: check-circom
    circom mantle/poc.circom --c --r1cs --no_asm --O2 --output mantle
    # circom-generated main() has no return on the success path; patch it before -O3 turns it into an infinite loop
    {{sed_i}} ':a;N;$!ba;s/\n}\n\n*$/\n  return 0;\n}/' mantle/poc_cpp/main.cpp
    cp -r {{src}}/poc mantle/poc_cpp/poc
    cp {{src}}/circom_adapter.cpp {{src}}/circom_adapter.hpp {{src}}/circom_fwd.hpp {{src}}/types.hpp mantle/poc_cpp/
    cp {{ci_makefile}} mantle/poc_cpp/Makefile
    cp mantle/test_poc.cpp mantle/poc_cpp/test_poc.cpp
    make -C mantle/poc_cpp PROJECT=poc linux-lib

# Run a simple smoke test of the PoC witness generator.
test-poc: poc
    g++ -std=c++11 -O3 -I mantle/poc_cpp mantle/poc_cpp/test_poc.cpp -L mantle/poc_cpp -lwitness_poc -lgmp -o mantle/poc_cpp/test_poc
    cd mantle/poc_cpp && ./test_poc

# Build the signature circuit and its C++ witness generator, equivalent to the CI build.
signature: check-circom
    circom mantle/signature.circom --c --r1cs --no_asm --O2 --output mantle
    # circom-generated main() has no return on the success path; patch it before -O3 turns it into an infinite loop
    {{sed_i}} ':a;N;$!ba;s/\n}\n\n*$/\n  return 0;\n}/' mantle/signature_cpp/main.cpp
    cp -r {{src}}/signature mantle/signature_cpp/signature
    cp {{src}}/circom_adapter.cpp {{src}}/circom_adapter.hpp {{src}}/circom_fwd.hpp {{src}}/types.hpp mantle/signature_cpp/
    cp {{ci_makefile}} mantle/signature_cpp/Makefile
    cp mantle/test_signature.cpp mantle/signature_cpp/test_signature.cpp
    make -C mantle/signature_cpp PROJECT=signature linux-lib

# Run a simple smoke test of the signature witness generator.
test-signature: signature
    g++ -std=c++11 -O3 -I mantle/signature_cpp mantle/signature_cpp/test_signature.cpp -L mantle/signature_cpp -lwitness_signature -lgmp -o mantle/signature_cpp/test_signature
    cd mantle/signature_cpp && ./test_signature

clean:
    rm -rf blend/poq_cpp mantle/pol_cpp mantle/poc_cpp mantle/signature_cpp
