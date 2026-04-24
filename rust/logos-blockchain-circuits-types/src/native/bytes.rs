use crate::ffi;

pub struct Bytes(Vec<u8>);

impl Bytes {
    #[must_use]
    pub fn inner(&self) -> &Vec<u8> {
        &self.0
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
