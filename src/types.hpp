#ifndef TYPES_HPP
#define TYPES_HPP

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define STATUS_MESSAGE_LENGTH 256

#ifdef __cplusplus
extern "C" {
#endif

/// Mutable byte buffer.
typedef struct Bytes {
    uint8_t* data;
    size_t size;
} Bytes;

/// Immutable byte buffer.
typedef struct ConstBytes {
    const uint8_t* data;
    size_t size;
} ConstBytes;

typedef enum StatusCode {
    StatusCode_Ok = 0,
    StatusCode_DynError = 1,
    StatusCode_InvalidInput = 2,
    StatusCode_OutOfMemory = 3,
} StatusCode;

static inline bool status_code_is_ok(const StatusCode code) {
    return code == StatusCode_Ok;
}

static inline bool status_code_is_error(const StatusCode code) {
    return !status_code_is_ok(code);
}

/// A status code with an optional human-readable description.
typedef struct Status {
    StatusCode code;
    char message[STATUS_MESSAGE_LENGTH];
} Status;

static inline Status status_new(const StatusCode code, const char* message) {
    Status status = {code, {}};
    if (message != NULL) {
        strncpy(status.message, message, STATUS_MESSAGE_LENGTH - 1);
    }
    return status;
}
static inline Status status_from_code(const StatusCode code) { return status_new(code, NULL); }
static inline Status status_ok() { return status_from_code(StatusCode_Ok); }

static inline bool status_is_ok(const Status status) { return status_code_is_ok(status.code); }
static inline bool status_is_error(const Status status) { return status_code_is_error(status.code); }

/// Inputs for witness generation.
typedef struct WitnessInput {
    /// Contents of the circuit's .dat file.
    const ConstBytes dat;
    /// Null-terminated JSON string of circuit inputs.
    const char* inputs_json;
} WitnessInput;

static inline void free_bytes(Bytes* bytes) {
    if (bytes == NULL) return;
    free(bytes->data);
    bytes->data = NULL;
    bytes->size = 0;
}

#ifdef __cplusplus
}
#endif

#endif // TYPES_HPP
