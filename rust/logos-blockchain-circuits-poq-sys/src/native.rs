use std::path::Path;
use lbc_types::{ffi, native::{Bytes, Error, WitnessInput}};
use crate::ffi::{poq_generate_witness, poq_generate_witness_from_files};

fn into_null_terminated_string(
    string: &str,
) -> Result<std::ffi::CString, Error> {
    std::ffi::CString::new(string)
        .map_err(|error| Error::InvalidInput(Some(format!("Could not convert string to CString: {error}"))))
}

fn path_as_null_terminated_string(
    path: &Path,
) -> Result<std::ffi::CString, Error> {
    let path = path.to_str().ok_or(Error::InvalidInput(Some(format!("Could not convert the path to a string: {}", path.display()))))?;
    into_null_terminated_string(path)
}

pub fn generate_witness(
    input: WitnessInput,
) -> Result<Bytes, Error> {
    let ffi_input_guard = input.as_ffi();
    let ffi_input = ffi_input_guard.as_ref();

    let mut ffi_output_bytes = ffi::Bytes::null();

    let status = unsafe {
        poq_generate_witness(
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
        poq_generate_witness_from_files (
            c_dat.as_ptr(),
            c_inputs.as_ptr(),
            c_output.as_ptr(),
        )
    }.try_into()
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;
    use lbc_types::native::WitnessInput;
    use std::sync::LazyLock;
    use super::{generate_witness, generate_witness_from_files};

    static LIB_DIR: LazyLock<PathBuf> = LazyLock::new(|| {
        PathBuf::from(
            std::env::var("POQ_LIB_DIR")
                .expect("POQ_LIB_DIR must be available, as provided by the build script."),
        )
    });
    static INPUTS: LazyLock<PathBuf> = LazyLock::new(|| {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("sample.input.json")
    });

    #[test]
    fn test_generate_witness() {
        let dat = LIB_DIR.join("witness_generator");
        let witness_output_path = std::env::temp_dir().join("poq_test_witness.wtns");

        generate_witness_from_files(&dat, &*INPUTS, &witness_output_path)
            .expect("generate_witness_from_files failed.");

        let dat_bytes = {
            let dat_file = dat.with_extension("dat");
            std::fs::read(&dat_file)
                .expect(format!("Failed to read {}.", dat_file.display()).as_str())
        };
        let inputs_json = std::fs::read_to_string(&*INPUTS)
            .expect(format!("Failed to read {}.", INPUTS.display()).as_str());

        let input = WitnessInput::new(dat_bytes.as_slice(), inputs_json).expect("Failed to construct the input for the witness generator.");
        let output = generate_witness(input).expect("generate_witness failed.");

        let expected = std::fs::read(&witness_output_path).expect(format!("Failed to read the generated witness from {}.", witness_output_path.display()).as_str());
        assert_eq!(output.as_slice(), expected.as_slice());
    }
}
