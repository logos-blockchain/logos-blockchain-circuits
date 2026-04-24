//! Raw `#[repr(C)]` types that mirror the C witness generator API.
//!
//! These types map directly to the C header structs and are used at the FFI boundary. Prefer the
//! wrappers in [`crate::native`] for ordinary Rust code.

pub mod status;
pub mod bytes;
pub mod witness_input;

pub use status::Status;
pub use bytes::{Bytes, ConstBytes, free_bytes};
pub use witness_input::WitnessInput;
