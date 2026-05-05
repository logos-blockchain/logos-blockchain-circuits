use std::path::Path;
use lbc_types::{ffi, native::{Bytes, Error}};
use lbc_types::inputs::CircuitDat;
use lbc_utils::string::path_as_null_terminated_string;
use crate::ffi::{signature_generate_witness, signature_generate_witness_from_files};

pub(crate) const RAW_CIRCUIT_DAT: &[u8] = include_bytes!(concat!(env!("LBC_SIGNATURE_LIB_DIR"), "/witness_generator.dat"));

pub struct SignatureDat;
impl CircuitDat for SignatureDat {
    const DAT: &'static [u8] = RAW_CIRCUIT_DAT;
}

pub type SignatureWitnessInput<'a> = lbc_types::inputs::CircuitWitnessInput<'a, SignatureDat>;

pub fn generate_witness(
    input: SignatureWitnessInput,
) -> Result<Bytes, Error> {
    let input: lbc_types::WitnessInput = input.into();
    let ffi_input_guard = input.as_ffi();
    let ffi_input = ffi_input_guard.as_ref();

    let mut ffi_output_bytes = ffi::Bytes::null();

    let status = unsafe {
        signature_generate_witness(
            ffi_input as *const ffi::WitnessInput,
            &mut ffi_output_bytes as *mut ffi::Bytes
        )
    };

    status.try_into().map(|()| { Bytes::from(ffi_output_bytes) })
}

pub fn generate_witness_from_files(
    dat: &Path,
    inputs: &Path,
    output: &Path,
) -> Result<(), Error> {
    let c_dat = path_as_null_terminated_string(dat)?;
    let c_inputs = path_as_null_terminated_string(inputs)?;
    let c_output = path_as_null_terminated_string(output)?;

    unsafe {
        signature_generate_witness_from_files(
            c_dat.as_ptr(),
            c_inputs.as_ptr(),
            c_output.as_ptr(),
        )
    }.try_into()
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;
    use std::sync::LazyLock;
    use super::{generate_witness, generate_witness_from_files, SignatureWitnessInput};

    static LIB_DIR: LazyLock<PathBuf> = LazyLock::new(|| {
        const ENV_VAR: &str = "LBC_SIGNATURE_LIB_DIR";
        PathBuf::from(
            std::env::var(ENV_VAR)
                .expect(format!("Environment variable '{ENV_VAR}' must be available, as provided by the build script.").as_str()),
        )
    });
    static INPUTS: LazyLock<PathBuf> = LazyLock::new(|| {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("sample.input.json")
    });

    #[test]
    fn test_generate_witness() {
        let dat = LIB_DIR.join("witness_generator");
        let witness_output_path = std::env::temp_dir().join("signature_test_witness.wtns");

        generate_witness_from_files(&dat, &*INPUTS, &witness_output_path)
            .expect("generate_witness_from_files failed.");

        let inputs_json = std::fs::read_to_string(&*INPUTS)
            .expect(format!("Failed to read {}.", INPUTS.display()).as_str());

        let input = SignatureWitnessInput::new(inputs_json).expect("Failed to construct the input for the witness generator.");
        let output = generate_witness(input).expect("generate_witness failed.");

        let expected = std::fs::read(&witness_output_path).expect(format!("Failed to read the generated witness from {}.", witness_output_path.display()).as_str());
        assert_eq!(output.as_slice(), expected.as_slice());
    }
}
