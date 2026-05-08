//! Rust-safe wrappers around the FFI types.
//!
//! Use them in preference to the types in [`crate::ffi`].

pub mod circuit_witness_input;
pub mod status;
pub mod witness;
pub mod witness_input;

pub use circuit_witness_input::{CircuitDat, CircuitWitnessInput};
pub use status::{Error, Result};
pub use witness::Witness;
pub use witness_input::WitnessInput;
