#ifndef TYPES_HPP
#define TYPES_HPP

#include <stddef.h>
#include <stdint.h>
#include <cassert>

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

namespace result {
    namespace status_code {
        /// Represents the outcome of an operation.
        enum StatusCode {
            Ok = 0,
            InvalidInput = 1,
        };

        inline bool is_ok(const StatusCode code) {
            return code == Ok;
        }

        inline bool is_error(const StatusCode code) {
            return code != Ok;
        }
    }

    using StatusCode = status_code::StatusCode;

    /// A status code with an optional human-readable description.
    struct Status {
        StatusCode code;
        const char* message = nullptr;

        Status() : code(StatusCode::Ok) {}
        explicit Status(const StatusCode code) : code(code) {}
        Status(const StatusCode code, const char* message) : code(code), message(message) {}

        bool is_ok() const { return status_code::is_ok(code); }
        bool is_error() const { return status_code::is_error(code); }
    };

    /// A result type that encapsulates either a successful value of type `T` or an error status.
    ///
    /// # Note
    ///
    /// There's no distinction between the `Ok` and `Error` variants at the type level.
    /// Instead, the `status` field indicates whether the result is successful or an error.
    /// Consumers are responsible for checking the status before accessing the value.
    template<typename T>
    struct Result {
        /// The result value. Undefined behavior if `is_error()`.
        T value;
        Status status;

        static Result ok(T value) { return Result{value, Status{}}; }
        /// Constructs an error result with a fallback value for non-default-constructible `T`.
        static Result error(const T fallback, const Status status) {
            assert(status.is_error() && "Result::error() called with Ok status.");
            return Result{fallback, status};
        }
        /// Constructs an error result. Requires `T` to be default-constructible.
        static Result error(const Status status) {
            return Result::error(T{}, status);
        }
        /// Constructs an error result from a status code. Requires `T` to be default-constructible.
        static Result error(const StatusCode status_code) {
            const Status status{status_code};
            return Result::error(status);
        }
        Result(T value, const Status status) : value(value), status(status) {}

        bool is_ok() const { return status.is_ok(); }
        bool is_error() const { return status.is_error(); }
    };
}

#endif // TYPES_HPP
