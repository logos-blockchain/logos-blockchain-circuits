use std::ffi::c_char;
use crate::ffi::ConstBytes;

/// Input to a witness generator function.
///
/// Both pointers must remain valid for the duration of the C call.
#[repr(C)]
pub struct WitnessInput {
    /// The circuit data file contents.
    pub dat: ConstBytes,
    /// Null-terminated JSON string containing the circuit inputs.
    pub inputs_json: *const c_char,
}
