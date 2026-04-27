use std::path::Path;
use lbc_types::{ffi, native::{Bytes, Error, WitnessInput}};
use crate::ffi::{poq_generate_witness, poq_generate_witness_from_files};

fn into_null_terminated_string(
    string: &str,
) -> Result<std::ffi::CString, Error> {
    std::ffi::CString::new(string)
        .map_err(|error| Error::InvalidInput(Some(format!("Could not convert string to CString: {error}"))))
}

fn path_as_null_terminated_string(
    path: &Path,
) -> Result<std::ffi::CString, Error> {
    let path = path.to_str().ok_or(Error::InvalidInput(Some(format!("Could not convert the path to a string: {}", path.display()))))?;
    into_null_terminated_string(path)
}

pub fn generate_witness(
    input: WitnessInput,
) -> Result<Bytes, Error> {
    let ffi_input_guard = input.as_ffi();
    let ffi_input = ffi_input_guard.as_ref();

    let mut ffi_output_bytes = ffi::Bytes::null();

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
    let c_dat = path_as_null_terminated_string(dat)?;
    let c_inputs = path_as_null_terminated_string(inputs)?;
    let c_output = path_as_null_terminated_string(output)?;

    unsafe {
        poq_generate_witness_from_files (
            c_dat.as_ptr(),
            c_inputs.as_ptr(),
            c_output.as_ptr(),
        )
    }.try_into()
}
