#ifndef TYPES_HPP
#define TYPES_HPP

#include <stddef.h>
#include <stdint.h>

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

#endif // TYPES_HPP
