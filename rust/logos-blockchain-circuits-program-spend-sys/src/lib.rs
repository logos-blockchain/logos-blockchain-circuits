mod ffi;
pub mod native;

pub use native::{
    ProgramSpendWitnessInput, artifacts, generate_witness, generate_witness_from_files,
};
