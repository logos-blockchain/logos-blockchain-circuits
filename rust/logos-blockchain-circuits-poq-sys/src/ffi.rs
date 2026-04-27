use std::ffi::c_char;
use lbc_types::ffi::{Bytes, Status, WitnessInput};

unsafe extern "C" {
    pub fn poq_generate_witness(input: *const WitnessInput, output: *mut Bytes) -> Status;

    pub fn poq_generate_witness_from_files(
        dat: *const c_char,
        inputs: *const c_char,
        output: *const c_char,
    ) -> Status;
}
