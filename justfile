cargo_root      := justfile_directory() + "/rust"
src             := justfile_directory() + "/src"
ci_makefile     := justfile_directory() + "/.github/resources/witness-generator/Makefile"
calcwit_fix     := justfile_directory() + "/.github/resources/witness-generator/fix_calcwit_leak.sh"
circom_version  := "2.2.2" # This version must match the version used in the CI

os := `uname -s`
sed_i := if os == "Darwin" { "sed -i ''" } else { "sed -i" }

# Shortcut to run cargo commands from the repo root (the Cargo workspace lives under ./rust/).
# Potentially temporary.
cargo +args:
    cd {{cargo_root}} && cargo {{args}}

# Verify the installed circom matches the pinned version.
check-circom:
    @circom --version | grep -qF "{{circom_version}}" || \
        (echo "circom {{circom_version}} required; got: $(circom --version 2>&1)" >&2; exit 1)

prettify:
    nix shell nixpkgs#clang-tools -c clang-format -i src/**.cpp src/**.hpp

# Run an input generator script.
# Output is written relative to the script's directory.
# Example: just gen-inputs blend/generate_inputs_for_poq.py 10 10 10 1
#   -> blend/input.json
gen-inputs script +args='':
    cd "$(dirname '{{script}}')" && python3 "$(basename '{{script}}')" {{args}}

# Build the PoQ circuit and its C++ witness generator, equivalent to the CI build.
poq: check-circom
    circom blend/poq.circom --c --r1cs --no_asm --O2 --output blend
    # circom-generated main() has no return on the success path; patch it before -O3 turns it into an infinite loop
    {{sed_i}} ':a;N;$!ba;s/\n}\n\n*$/\n  return 0;\n}/' blend/poq_cpp/main.cpp
    # circom's empty ~Circom_CalcWit destructor leaks per call when linked as a library; free the per-call allocations
    sh {{calcwit_fix}} blend/poq_cpp
    cp -r {{src}}/poq blend/poq_cpp/poq
    cp {{src}}/circom_adapter.cpp {{src}}/circom_adapter.hpp {{src}}/circom_fwd.hpp {{src}}/types.hpp {{src}}/assert.h blend/poq_cpp/
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
    # circom's empty ~Circom_CalcWit destructor leaks per call when linked as a library; free the per-call allocations
    sh {{calcwit_fix}} mantle/pol_cpp
    cp -r {{src}}/pol mantle/pol_cpp/pol
    cp {{src}}/circom_adapter.cpp {{src}}/circom_adapter.hpp {{src}}/circom_fwd.hpp {{src}}/types.hpp {{src}}/assert.h mantle/pol_cpp/
    cp {{ci_makefile}} mantle/pol_cpp/Makefile
    cp mantle/test_pol.cpp mantle/pol_cpp/test_pol.cpp
    make -C mantle/pol_cpp PROJECT=pol linux-lib

# Run a simple smoke test of the PoL witness generator.
test-pol: pol
    g++ -std=c++11 -O3 -I mantle/pol_cpp mantle/pol_cpp/test_pol.cpp -L mantle/pol_cpp -lwitness_pol -lgmp -o mantle/pol_cpp/test_pol
    cd mantle/pol_cpp && ./test_pol

# Build the transfer circuit and its C++ witness generator, equivalent to the CI build.
transfer: check-circom
    circom mantle/transfer.circom --c --r1cs --no_asm --O2 --output mantle
    # circom-generated main() has no return on the success path; patch it before -O3 turns it into an infinite loop
    {{sed_i}} ':a;N;$!ba;s/\n}\n\n*$/\n  return 0;\n}/' mantle/transfer_cpp/main.cpp
    # circom's empty ~Circom_CalcWit destructor leaks per call when linked as a library; free the per-call allocations
    sh {{calcwit_fix}} mantle/transfer_cpp
    cp -r {{src}}/transfer mantle/transfer_cpp/transfer
    cp {{src}}/circom_adapter.cpp {{src}}/circom_adapter.hpp {{src}}/circom_fwd.hpp {{src}}/types.hpp {{src}}/assert.h mantle/transfer_cpp/
    cp {{ci_makefile}} mantle/transfer_cpp/Makefile
    cp mantle/test_transfer.cpp mantle/transfer_cpp/test_transfer.cpp
    make -C mantle/transfer_cpp PROJECT=transfer linux-lib

# Run a simple smoke test of the transfer witness generator.
test-transfer: transfer
    g++ -std=c++11 -O3 -I mantle/transfer_cpp mantle/transfer_cpp/test_transfer.cpp -L mantle/transfer_cpp -lwitness_transfer -lgmp -o mantle/transfer_cpp/test_transfer
    cd mantle/transfer_cpp && ./test_transfer

# Build the program spend circuit and its C++ witness generator, equivalent to the CI build.
program_spend: check-circom
    circom mantle/program_spend.circom --c --r1cs --no_asm --O2 --output mantle
    # circom-generated main() has no return on the success path; patch it before -O3 turns it into an infinite loop
    {{sed_i}} ':a;N;$!ba;s/\n}\n\n*$/\n  return 0;\n}/' mantle/program_spend_cpp/main.cpp
    # circom's empty ~Circom_CalcWit destructor leaks per call when linked as a library; free the per-call allocations
    sh {{calcwit_fix}} mantle/program_spend_cpp
    cp -r {{src}}/program_spend mantle/program_spend_cpp/program_spend
    cp {{src}}/circom_adapter.cpp {{src}}/circom_adapter.hpp {{src}}/circom_fwd.hpp {{src}}/types.hpp {{src}}/assert.h mantle/program_spend_cpp/
    cp {{ci_makefile}} mantle/program_spend_cpp/Makefile
    cp mantle/test_program_spend.cpp mantle/program_spend_cpp/test_program_spend.cpp
    make -C mantle/program_spend_cpp PROJECT=program_spend linux-lib

# Run a simple smoke test of the program spend witness generator.
test-program_spend: program_spend
    g++ -std=c++11 -O3 -I mantle/program_spend_cpp mantle/program_spend_cpp/test_program_spend.cpp -L mantle/program_spend_cpp -lwitness_program_spend -lgmp -o mantle/program_spend_cpp/test_program_spend
    cd mantle/program_spend_cpp && ./test_program_spend

clean:
    rm -rf blend/poq_cpp mantle/pol_cpp mantle/transfer_cpp mantle/program_spend_cpp
