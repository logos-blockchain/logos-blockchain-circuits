use std::ffi::CString;

use crate::{ffi, native::Error};

/// Input for witness generators
pub struct WitnessInput<'dat> {
    /// The circuit's dat file contents.
    dat: &'dat [u8],
    /// The JSON string containing the circuit inputs.
    inputs_json: CString,
}

impl<'dat> WitnessInput<'dat> {
    pub fn new(dat: &'dat [u8], inputs_json: String) -> Result<Self, Error> {
        let inputs_json = CString::new(inputs_json).map_err(|error| {
            Error::InvalidInput(Some(format!(
                "The parameter inputs_json could not be converted to C string: {error}"
            )))
        })?;
        Ok(Self { dat, inputs_json })
    }

    /// Borrows this value as a temporary FFI-compatible view.
    #[must_use]
    pub fn as_ffi(&'_ self) -> WitnessInputFfiGuard<'_> {
        WitnessInputFfiGuard::new(self)
    }
}

/// Temporary FFI view of a [`WitnessInput`], which makes [`ffi::WitnessInput`]
/// lifetime-aware.
pub struct WitnessInputFfiGuard<'dat> {
    ffi: ffi::WitnessInput,
    _lifetime: std::marker::PhantomData<&'dat WitnessInput<'dat>>,
}

impl<'dat> WitnessInputFfiGuard<'dat> {
    fn new(inner: &'dat WitnessInput) -> Self {
        let dat = ffi::ConstBytes {
            data: inner.dat.as_ptr(),
            size: inner.dat.len(),
        };
        let inputs_json = inner.inputs_json.as_ptr();
        let ffi = ffi::WitnessInput { dat, inputs_json };
        Self {
            ffi,
            _lifetime: std::marker::PhantomData,
        }
    }
}

impl AsRef<ffi::WitnessInput> for WitnessInputFfiGuard<'_> {
    fn as_ref(&self) -> &ffi::WitnessInput {
        &self.ffi
    }
}
