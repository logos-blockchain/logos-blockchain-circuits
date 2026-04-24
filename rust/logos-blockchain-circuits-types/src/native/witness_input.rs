use std::ffi::{c_char, CString, NulError};
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

    pub fn as_ffi(&'_ self) -> Result<WitnessInputFfiGuard<'_>, NulError> {
        WitnessInputFfiGuard::new(self)
    }
}

/// Temporary FFI view of a [`WitnessInput`], valid for the lifetime of the source.
///
/// Owns the C string allocation of `WitnessInput::inputs_json` and ensures it is freed when
/// dropped.
pub struct WitnessInputFfiGuard<'a> {
    ffi: ffi::WitnessInput,
    _lifetime: std::marker::PhantomData<&'a WitnessInput>,
}

impl<'a> WitnessInputFfiGuard<'a> {
    fn new(inner: &'a WitnessInput) -> Result<Self, NulError> {
        let dat = ffi::ConstBytes { data: inner.dat.as_ptr(), size: inner.dat.len() };
        let inputs_json = CString::new(inner.inputs_json.clone())?.into_raw();
        let ffi = ffi::WitnessInput { dat, inputs_json };
        Ok(Self {
            ffi,
            _lifetime: std::marker::PhantomData,
        })
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
