use std::ffi::CString;
use crate::ffi;
use crate::native::Error;

/// Input for witness generators
pub struct WitnessInput<'a> {
    /// The circuit's dat file contents.
    dat: &'a [u8],
    /// The JSON string containing the circuit inputs.
    inputs_json: CString,
}

impl<'a> WitnessInput<'a> {
    pub fn new(dat: &'a [u8], inputs_json: String) -> Result<Self, Error> {
        let inputs_json = CString::new(inputs_json).map_err(
            |error| Error::InvalidInput(Some(
                format!("The parameter inputs_json could not be converted to CString: {}", error)
            ))
        )?;
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
    _lifetime: std::marker::PhantomData<&'a WitnessInput<'a>>,
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
