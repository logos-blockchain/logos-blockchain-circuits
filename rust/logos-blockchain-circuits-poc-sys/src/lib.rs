mod ffi;
pub mod native;

#[cfg(feature = "embed-circuit")]
pub use native::embedded::{PocWitnessInput, generate_witness};
pub use native::{artifacts, generate_witness_from_files};
