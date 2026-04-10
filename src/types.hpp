#ifndef TYPES_HPP
#define TYPES_HPP

#include <cstddef>
#include <cstdint>

/// A pointer to a contiguous sequence of elements with a known length.
///
/// # Parameters
///
/// - `T`: The element type. Use `const T` for immutable data.
template<typename T>
struct Slice {
    /// Pointer to the first element.
    T* data;
    /// Number of elements.
    size_t size;
};

/// Mutable byte buffer.
using Bytes = Slice<uint8_t>;

/// Immutable byte buffer.
using ConstBytes = Slice<const uint8_t>;

namespace status {
    /// Represents the outcome of an operation.
    enum StatusCode {
        Ok = 0,
        DynError = 1,
        InvalidInput = 2,
        OutOfMemory = 3,
    };

    inline bool is_ok(const StatusCode code) {
        return code == Ok;
    }

    inline bool is_error(const StatusCode code) {
        return !is_ok(code);
    }

    /// A status code with an optional human-readable description.
    struct Status {
        StatusCode code;
        const char* message;
    };

    inline Status from_code(const StatusCode code) { return Status { code, nullptr }; }
    inline Status ok() { return from_code(Ok); }

    inline bool is_ok(const Status status) { return is_ok(status.code); }
    inline bool is_error(const Status status) { return is_error(status.code); }

}

#endif // TYPES_HPP
