#include "types.hpp"

#include <cstdlib>

extern "C" void free_bytes(Bytes* bytes) {
    if (bytes == nullptr) {
        return;
    }

    free(bytes->data);
    bytes->data = nullptr;
    bytes->size = 0;
}
