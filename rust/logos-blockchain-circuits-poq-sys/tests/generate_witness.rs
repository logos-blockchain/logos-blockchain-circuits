use std::path::PathBuf;
use logos_blockchain_circuits_poq_sys::{generate_witness, generate_witness_from_files};
use lbc_types::native::WitnessInput;

fn lib_dir() -> PathBuf {
    PathBuf::from(
        std::env::var("POQ_LIB_DIR").expect("POQ_LIB_DIR must point to the poq library directory"),
    )
}

fn inputs_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../blend/poq-input.json")
}

#[test]
fn generate_witness_matches_from_files() {
    let dat = lib_dir().join("witness_generator");
    let inputs = inputs_path();
    let witness_path = std::env::temp_dir().join("poq_test_witness.wtns");

    generate_witness_from_files(&dat, &inputs, &witness_path)
        .expect("generate_witness_from_files failed");

    let dat_bytes = std::fs::read(dat.with_extension("dat"))
        .expect("failed to read witness_generator.dat");
    let inputs_json = std::fs::read_to_string(&inputs).expect("failed to read poq-input.json");

    let input = WitnessInput::new(dat_bytes.as_slice(), inputs_json).expect("failed to construct WitnessInput");
    let output = generate_witness(input).expect("generate_witness failed");

    let expected = std::fs::read(&witness_path).expect("failed to read witness output file");
    assert_eq!(output.as_slice(), expected.as_slice());
}
