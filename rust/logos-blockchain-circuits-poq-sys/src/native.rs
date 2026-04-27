use std::ffi::c_char;
use std::path::Path;
use lbc_types::{ffi, native::{Bytes, Error, WitnessInput}};
use crate::ffi::{poq_generate_witness, poq_generate_witness_from_files};

pub fn generate_witness(
    input: WitnessInput,
) -> Result<Bytes, Error> {
    let ffi_input_guard = input.as_ffi();
    let ffi_input = ffi_input_guard.as_ref();

    let mut ffi_output_bytes = ffi::Bytes {
        data: std::ptr::null_mut(),
        size: 0
    };

    let status = unsafe {
        poq_generate_witness(
            ffi_input as *const ffi::WitnessInput,
            &mut ffi_output_bytes as *mut ffi::Bytes
        )
    };

    status.try_into().map(|()| { Bytes::from(ffi_output_bytes) })
}

pub fn generate_witness_from_files(
    dat: &Path,
    inputs: &Path,
    output: &Path,
) -> Result<(), Error> {
    let dat = dat.to_str().ok_or_else(|| Error::InvalidInput)?; // TODO: Message
    let inputs = inputs.to_str().ok_or_else(|| Error::InvalidInput)?;
    let output = output.to_str().ok_or_else(|| Error::InvalidInput)?;

    unsafe {
        poq_generate_witness_from_files (
            dat.as_ptr() as *const c_char,
            inputs.as_ptr() as *const c_char,
            output.as_ptr() as *const c_char
        )
    }.try_into()
}
