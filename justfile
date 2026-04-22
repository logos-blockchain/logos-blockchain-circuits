src          := justfile_directory() + "/src"
ci_makefile  := justfile_directory() + "/.github/resources/witness-generator/Makefile"

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
poq:
    circom blend/poq.circom --c --r1cs --no_asm --O2 --output blend
    # circom-generated main() has no return on the success path; patch it before -O3 turns it into an infinite loop
    sed -i ':a;N;$!ba;s/\n}\n\n*$/\n  return 0;\n}/' blend/poq_cpp/main.cpp
    cp -r {{src}}/poq blend/poq_cpp/poq
    cp {{src}}/circom_adapter.cpp {{src}}/circom_adapter.hpp {{src}}/circom_fwd.hpp {{src}}/types.hpp blend/poq_cpp/
    cp {{ci_makefile}} blend/poq_cpp/Makefile
    cp blend/test_ffi.cpp blend/poq_cpp/test_ffi.cpp
    make -C blend/poq_cpp PROJECT=poq linux-lib

# Run a simple smoke test of the PoQ witness generator.
test-poq: poq
    g++ -std=c++11 -O3 -I blend/poq_cpp blend/poq_cpp/test_ffi.cpp -L blend/poq_cpp -lwitness_poq -lgmp -o blend/poq_cpp/test_ffi
    cd blend/poq_cpp && ./test_ffi

clean:
    rm -rf blend/poq_cpp
