use std::ffi::c_char;
use crate::ffi::ConstBytes;

#[repr(C)]
pub struct WitnessInput {
    pub dat: ConstBytes,
    pub inputs_json: *const c_char,
}
