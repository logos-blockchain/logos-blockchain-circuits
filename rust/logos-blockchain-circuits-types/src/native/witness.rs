use crate::ffi;

/// Byte buffer
///
/// When constructing from [`From<ffi::Bytes>`], it takes ownership of the underlying value and
/// frees it.
pub type Witness = bytes::Bytes;

impl From<ffi::Bytes> for Witness {
    fn from(mut ffi_value: ffi::Bytes) -> Self {
        let vec = if ffi_value.size == 0 || ffi_value.data.is_null() {
            Vec::new()
        } else {
            // SAFETY: `ffi_value.data` is non-null and `ffi_value.size > 0` (checked above),
            // pointing to a valid C-allocated buffer of at least `size` bytes.
            unsafe { std::slice::from_raw_parts(ffi_value.data, ffi_value.size).to_vec() }
        };
        // SAFETY: `ffi_value` is a local variable, so the raw pointer is valid for this call.
        unsafe { ffi::free_bytes(&raw mut ffi_value) };
        Self::from(vec)
    }
}
