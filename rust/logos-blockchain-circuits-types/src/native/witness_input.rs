use std::ffi::{CString, NulError};
use crate::ffi;

/// Input for witness generators
pub struct WitnessInput {
    /// The circuit's dat file contents.
    dat: Vec<u8>,
    /// The JSON string containing the circuit inputs.
    inputs_json: CString,
}

impl WitnessInput {
    pub fn new(dat: Vec<u8>, inputs_json: String) -> Result<Self, NulError> {
        let inputs_json = CString::new(inputs_json)?;
        Ok(Self { dat, inputs_json })
    }

    /// Borrows this value as a temporary FFI-compatible view.
    pub fn as_ffi(&'_ self) -> WitnessInputFfiGuard<'_> {
        WitnessInputFfiGuard::new(self)
    }
}

/// Temporary FFI view of a [`WitnessInput`], which makes [`ffi::WitnessInput`] lifetime-aware.
pub struct WitnessInputFfiGuard<'a> {
    ffi: ffi::WitnessInput,
    _lifetime: std::marker::PhantomData<&'a WitnessInput>,
}

impl<'a> WitnessInputFfiGuard<'a> {
    fn new(inner: &'a WitnessInput) -> Self {
        let dat = ffi::ConstBytes { data: inner.dat.as_ptr(), size: inner.dat.len() };
        let inputs_json = inner.inputs_json.as_ptr();
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
