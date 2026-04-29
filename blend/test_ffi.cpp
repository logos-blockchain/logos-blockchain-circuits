#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "poq/ffi.hpp"

static uint8_t* read_file(const char* path, size_t* out_size) {
    FILE* f = fopen(path, "rb");
    if (!f) return nullptr;
    fseek(f, 0, SEEK_END);
    *out_size = ftell(f);
    rewind(f);
    uint8_t* buf = (uint8_t*)malloc(*out_size + 1);
    fread(buf, 1, *out_size, f);
    buf[*out_size] = '\0';
    fclose(f);
    return buf;
}

int main() {
    Status status = poq_generate_witness_from_files(
        "poq",
        "../poq-input.json",
        "witness.wtns"
    );

    if (status_is_error(status)) {
        fprintf(stderr, "Error [%d]: %s\n", status.code, status.message);
        return 1;
    }

    printf("generate_witness_from_files: OK\n");

    size_t dat_size, json_size;
    uint8_t* dat_data = read_file("poq.dat", &dat_size);
    uint8_t* json_data = read_file("../poq-input.json", &json_size);

    WitnessInput input = {
        {dat_data, dat_size},
        (const char*)json_data
    };
    Bytes output = {nullptr, 0};

    status = poq_generate_witness(&input, &output);

    free(dat_data);
    free(json_data);

    if (status_is_error(status)) {
        fprintf(stderr, "Error [%d]: %s\n", status.code, status.message);
        return 1;
    }

    size_t wtns_size;
    uint8_t* wtns_data = read_file("witness.wtns", &wtns_size);
    assert(wtns_data != nullptr);
    assert(output.size == wtns_size);
    assert(memcmp(output.data, wtns_data, output.size) == 0);
    free(wtns_data);

    printf("generate_witness: OK (%zu bytes, matches witness.wtns)\n", output.size);
    free_bytes(&output);
    return 0;
}
