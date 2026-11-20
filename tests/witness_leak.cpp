// Calls `<circuit>_generate_witness` several times, to run under valgrind.
//
// Build with `-DGENERATE_WITNESS=<circuit>_generate_witness` and `ffi.hpp` on the include path.
// Usage: witness_leak <circuit.dat> <inputs.json> [iterations]

#include <stdio.h>
#include <stdlib.h>

#include "ffi.hpp"

#ifndef GENERATE_WITNESS
#error "GENERATE_WITNESS is not defined. E.g.: -DGENERATE_WITNESS=pol_generate_witness"
#endif

static uint8_t* read_file(const char* path, size_t* out_size) {
    FILE* f = fopen(path, "rb");
    if (f == nullptr) return nullptr;
    fseek(f, 0, SEEK_END);
    *out_size = ftell(f);
    rewind(f);
    uint8_t* buf = (uint8_t*)malloc(*out_size + 1);
    if (fread(buf, 1, *out_size, f) != *out_size) {
        free(buf);
        fclose(f);
        return nullptr;
    }
    buf[*out_size] = '\0';
    fclose(f);
    return buf;
}

int main(int argc, char** argv) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <circuit.dat> <inputs.json> [iterations]\n", argv[0]);
        return 2;
    }
    const int iterations = argc > 3 ? atoi(argv[3]) : 3;

    size_t dat_size = 0;
    size_t json_size = 0;
    uint8_t* dat = read_file(argv[1], &dat_size);
    uint8_t* json = read_file(argv[2], &json_size);
    if (dat == nullptr || json == nullptr) {
        fprintf(stderr, "Could not read %s or %s.\n", argv[1], argv[2]);
        return 2;
    }

    int code = 0;
    for (int i = 0; i < iterations; i++) {
        WitnessInput input = {{dat, dat_size}, (const char*)json};
        Bytes output = {nullptr, 0};
        const Status status = GENERATE_WITNESS(&input, &output);
        if (status_is_error(status)) {
            fprintf(stderr, "Error [%d]: %s\n", status.code, status.message);
            code = 1;
            break;
        }
        free(output.data);
    }

    free(dat);
    free(json);
    if (code == 0) printf("%d witness(es): OK\n", iterations);
    return code;
}
