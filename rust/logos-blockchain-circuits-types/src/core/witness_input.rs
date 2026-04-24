use std::ffi::{c_char, CString};
use crate::ffi;

pub struct WitnessInput {
    dat: Vec<u8>,
    inputs_json: String,
}

impl WitnessInput {
    #[must_use]
    pub const fn new(dat: Vec<u8>, inputs_json: String) -> Self {
        Self { dat, inputs_json }
    }

    #[must_use]
    pub fn as_ffi(&'_ self) -> WitnessInputFfiGuard<'_> {
        WitnessInputFfiGuard::new(self)
    }
}

/// Represents a guard for managing the lifetime of a WitnessInput in FFI.
/// This struct ensures that the memory allocated for the FFI representation of WitnessInput is
/// properly released when it goes out of scope.
pub struct WitnessInputFfiGuard<'a> {
    ffi: ffi::WitnessInput,
    _lifetime: std::marker::PhantomData<&'a WitnessInput>,
}

impl<'a> WitnessInputFfiGuard<'a> {
    #[must_use]
    pub fn new(inner: &'a WitnessInput) -> Self {
        let dat = ffi::ConstBytes { data: inner.dat.as_ptr(), size: inner.dat.len() };
        let inputs_json = CString::new(inner.inputs_json.clone()).expect("CString::new failed").into_raw();
        let ffi = ffi::WitnessInput { dat, inputs_json };
        Self {
            ffi,
            _lifetime: std::marker::PhantomData,
        }
    }
}

impl<'a> AsRef<ffi::WitnessInput> for WitnessInputFfiGuard<'a> {
    fn as_ref(&self) -> &ffi::WitnessInput {
        &self.ffi
    }
}

impl<'a> Drop for WitnessInputFfiGuard<'a> {
    fn drop(&mut self) {
        if !self.ffi.inputs_json.is_null() {
            drop(unsafe {
                CString::from_raw(self.ffi.inputs_json as *mut c_char)
            })
        }
    }
}

