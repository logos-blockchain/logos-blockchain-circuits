use crate::ffi;

/// Byte buffer
///
/// When constructing from [`From<ffi::Bytes>`], it takes ownership of the underlying value and
/// frees it.
pub struct Bytes(Vec<u8>);

impl Bytes {
    #[must_use]
    pub fn into_inner(self) -> Vec<u8> {
        self.0
    }

    #[must_use]
    pub fn as_slice(&self) -> &[u8] {
        &self.0
    }
}

impl From<Vec<u8>> for Bytes {
    fn from(value: Vec<u8>) -> Self {
        Self(value)
    }
}

impl From<ffi::Bytes> for Bytes {
    fn from(mut ffi_value: ffi::Bytes) -> Self {
        let raw = unsafe {
            std::slice::from_raw_parts(ffi_value.data, ffi_value.size).to_vec()
        };
        unsafe { ffi::free_bytes(&mut ffi_value); }
        Self(raw)
    }
}
