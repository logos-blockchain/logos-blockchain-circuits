//! Rust-safe wrappers around the FFI types.
//!
//! Use them in preference to the types in [`crate::ffi`].

pub mod bytes;
pub mod status;
pub mod witness_input;

pub use bytes::Bytes;
pub use status::{Result, Error};
pub use witness_input::WitnessInput;
