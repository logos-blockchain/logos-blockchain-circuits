use std::path::Path;

use lbc_common::string::path_as_null_terminated_string;
use lbc_types::{
    ffi,
    native::{Error, Witness},
};

use crate::ffi::{poq_generate_witness, poq_generate_witness_from_files};

lbc_common::circuit_artifacts!("poq");

pub struct PoqDat;
impl<'dat> lbc_types::CircuitDat<'dat> for PoqDat {
    const DAT: &'dat [u8] = artifacts::CIRCUIT_DAT;
}

pub type PoqWitnessInput<'dat> = lbc_types::CircuitWitnessInput<'dat, PoqDat>;

pub fn generate_witness(input: &PoqWitnessInput) -> Result<Witness, Error> {
    let ffi_input_guard = input.as_ffi();
    let ffi_input = ffi_input_guard.as_ref();

    let mut ffi_output_bytes = ffi::Bytes::null();

    // SAFETY: ffi_input is a valid pointer and ffi_output_bytes is a locally
    // initialized null Bytes.
    let status =
        unsafe { poq_generate_witness(std::ptr::from_ref(ffi_input), &raw mut ffi_output_bytes) };

    status.try_into().map(|()| Witness::from(ffi_output_bytes))
}

pub fn generate_witness_from_files(dat: &Path, inputs: &Path, output: &Path) -> Result<(), Error> {
    let c_dat = path_as_null_terminated_string(dat)?;
    let c_inputs = path_as_null_terminated_string(inputs)?;
    let c_output = path_as_null_terminated_string(output)?;

    // SAFETY: c_dat, c_inputs, and c_output are valid null-terminated C strings for
    // the duration of the call.
    unsafe { poq_generate_witness_from_files(c_dat.as_ptr(), c_inputs.as_ptr(), c_output.as_ptr()) }
        .try_into()
}

#[cfg(test)]
mod tests {
    use std::{path::PathBuf, sync::LazyLock};

    use super::{PoqWitnessInput, generate_witness, generate_witness_from_files};

    static LIB_DIR: LazyLock<PathBuf> =
        LazyLock::new(|| PathBuf::from(env!("LBC_ROOT_DIR")).join("poq"));
    static INPUTS: LazyLock<PathBuf> =
        LazyLock::new(|| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("sample.input.json"));

    #[test]
    fn test_generate_witness_invalid_json_returns_err() {
        let input = PoqWitnessInput::new("{".to_owned()).unwrap();
        assert!(generate_witness(&input).is_err());
    }

    #[test]
    fn test_generate_witness_missing_inputs_returns_err() {
        let input = PoqWitnessInput::new("{}".to_owned()).unwrap();
        assert!(generate_witness(&input).is_err());
    }

    #[test]
    fn test_generate_witness_constraint_violation_returns_err() {
        let json = std::fs::read_to_string(&*INPUTS).unwrap();
        let mut inputs: serde_json::Value = serde_json::from_str(&json).unwrap();
        inputs["core_root"] = serde_json::json!("1");
        let input = PoqWitnessInput::new(serde_json::to_string(&inputs).unwrap()).unwrap();
        assert!(generate_witness(&input).is_err());
    }

    #[test]
    fn test_generate_witness() {
        let dat = LIB_DIR.join("witness_generator");
        let witness_output_path = std::env::temp_dir().join("poq_test_witness.wtns");

        generate_witness_from_files(&dat, &INPUTS, &witness_output_path)
            .expect("generate_witness_from_files failed.");

        let inputs_json = std::fs::read_to_string(&*INPUTS)
            .unwrap_or_else(|_| panic!("Failed to read {}.", INPUTS.display()));

        let input = PoqWitnessInput::new(inputs_json)
            .expect("Failed to construct the input for the witness generator.");
        let output = generate_witness(&input).expect("generate_witness failed.");

        let expected = std::fs::read(&witness_output_path).unwrap_or_else(|_| {
            panic!(
                "Failed to read the generated witness from {}.",
                witness_output_path.display()
            )
        });
        assert_eq!(output.as_ref().iter().as_slice(), expected.as_slice());
    }
}
