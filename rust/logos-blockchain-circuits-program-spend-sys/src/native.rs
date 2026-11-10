use std::path::Path;

use lbc_common::string::path_as_null_terminated_string;
use lbc_types::{
    ffi,
    native::{Error, Witness},
};

use crate::ffi::{program_spend_generate_witness, program_spend_generate_witness_from_files};

lbc_common::circuit_artifacts!("program_spend");

pub struct ProgramSpendDat;
impl<'dat> lbc_types::CircuitDat<'dat> for ProgramSpendDat {
    const DAT: &'dat [u8] = artifacts::CIRCUIT_DAT;
}

pub type ProgramSpendWitnessInput<'dat> = lbc_types::CircuitWitnessInput<'dat, ProgramSpendDat>;

pub fn generate_witness(input: &ProgramSpendWitnessInput) -> Result<Witness, Error> {
    let ffi_input_guard = input.as_ffi();
    let ffi_input = ffi_input_guard.as_ref();

    let mut ffi_output_bytes = ffi::Bytes::null();

    // SAFETY: ffi_input is a valid pointer and ffi_output_bytes is a locally
    // initialized null Bytes.
    let status = unsafe {
        program_spend_generate_witness(std::ptr::from_ref(ffi_input), &raw mut ffi_output_bytes)
    };

    status.try_into().map(|()| Witness::from(ffi_output_bytes))
}

pub fn generate_witness_from_files(dat: &Path, inputs: &Path, output: &Path) -> Result<(), Error> {
    let c_dat = path_as_null_terminated_string(dat)?;
    let c_inputs = path_as_null_terminated_string(inputs)?;
    let c_output = path_as_null_terminated_string(output)?;

    // SAFETY: c_dat, c_inputs, and c_output are valid null-terminated C strings for
    // the duration of the call.
    unsafe {
        program_spend_generate_witness_from_files(
            c_dat.as_ptr(),
            c_inputs.as_ptr(),
            c_output.as_ptr(),
        )
    }
    .try_into()
}

#[cfg(test)]
mod tests {
    use std::{path::PathBuf, sync::LazyLock};

    use super::{
        Error, ProgramSpendWitnessInput, Witness, generate_witness, generate_witness_from_files,
    };

    static LIB_DIR: LazyLock<PathBuf> =
        LazyLock::new(|| PathBuf::from(env!("LBC_ROOT_DIR")).join("program_spend"));
    static INPUTS: LazyLock<PathBuf> =
        LazyLock::new(|| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("sample.input.json"));

    #[test]
    fn test_generate_witness_invalid_json_returns_err() {
        let input = ProgramSpendWitnessInput::new("{".to_owned()).unwrap();
        assert!(generate_witness(&input).is_err());
    }

    #[test]
    fn test_generate_witness_missing_inputs_returns_err() {
        let input = ProgramSpendWitnessInput::new("{}".to_owned()).unwrap();
        assert!(generate_witness(&input).is_err());
    }

    #[test]
    fn test_generate_witness_constraint_violation_returns_err() {
        let json = std::fs::read_to_string(&*INPUTS).unwrap();
        let mut inputs: serde_json::Value = serde_json::from_str(&json).unwrap();
        inputs["tx_cm_root"] = serde_json::json!("1");
        let input = ProgramSpendWitnessInput::new(serde_json::to_string(&inputs).unwrap()).unwrap();
        assert!(generate_witness(&input).is_err());
    }

    fn sample_inputs() -> serde_json::Value {
        let json = std::fs::read_to_string(&*INPUTS).unwrap();
        serde_json::from_str(&json).unwrap()
    }

    fn value(field: &serde_json::Value) -> u64 {
        field.as_str().unwrap().parse().unwrap()
    }

    fn generate(inputs: &serde_json::Value) -> Result<Witness, Error> {
        let input = ProgramSpendWitnessInput::new(serde_json::to_string(inputs).unwrap()).unwrap();
        generate_witness(&input)
    }

    #[test]
    fn test_generate_witness_input_after_inactive_input_returns_err() {
        // The sample consumes the notes of inputs 0 and 1. Input 1 alone stays
        // active, its value balanced by `paid_value`, so the nonces of the outputs
        // would be free if the active inputs did not have to come first.
        let mut inputs = sample_inputs();
        let paid_value = value(&inputs["paid_value"]) + value(&inputs["inputs_value"][0]);
        inputs["inputs_active"][0] = serde_json::json!("0");
        inputs["inputs_value"][0] = serde_json::json!("0");
        inputs["paid_value"] = serde_json::json!(paid_value.to_string());
        assert!(generate(&inputs).is_err());
    }

    #[test]
    fn test_generate_witness_no_input_picks_nonces() {
        // A step consuming no note of the program picks the nonces of its outputs:
        // the `op_id` binding the proof covers the output commitments.
        let mut inputs = sample_inputs();
        let paid_value = value(&inputs["paid_value"])
            + value(&inputs["inputs_value"][0])
            + value(&inputs["inputs_value"][1]);
        for i in 0..4 {
            inputs["inputs_active"][i] = serde_json::json!("0");
            inputs["inputs_value"][i] = serde_json::json!("0");
        }
        for k in 0..8 {
            inputs["outputs_nonce"][k] = serde_json::json!((k + 1).to_string());
        }
        inputs["paid_value"] = serde_json::json!(paid_value.to_string());
        assert!(generate(&inputs).is_ok());
    }

    #[test]
    fn test_generate_witness_same_note_in_two_inputs_returns_err() {
        // Input 1 consumes the note of input 0 again, `paid_value` balancing the
        // difference of value, so the note would be counted twice.
        let mut inputs = sample_inputs();
        let paid_value = value(&inputs["paid_value"]) + value(&inputs["inputs_value"][1])
            - value(&inputs["inputs_value"][0]);
        for field in [
            "inputs_stake_pk",
            "inputs_nonce",
            "inputs_value",
            "inputs_data",
            "inputs_selectors",
            "inputs_path",
        ] {
            inputs[field][1] = inputs[field][0].clone();
        }
        inputs["paid_value"] = serde_json::json!(paid_value.to_string());
        assert!(generate(&inputs).is_err());
    }

    #[test]
    fn test_generate_witness() {
        let dat = LIB_DIR.join("witness_generator");
        let witness_output_path = std::env::temp_dir().join("program_spend_test_witness.wtns");

        generate_witness_from_files(&dat, &INPUTS, &witness_output_path)
            .expect("generate_witness_from_files failed.");

        let inputs_json = std::fs::read_to_string(&*INPUTS)
            .unwrap_or_else(|_| panic!("Failed to read {}.", INPUTS.display()));

        let input = ProgramSpendWitnessInput::new(inputs_json)
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
