#[cfg(test)]
mod tests {
    use lbc_poq_sys::PoqWitnessInput;
    use logos_blockchain_circuits_tests::inputs;

    #[test]
    fn test_both_circuits_generate_witness() {
        let pol_inputs_raw = std::fs::read_to_string(inputs::POL.as_path()).unwrap();
        let pol_witness_input = lbc_pol_sys::PolWitnessInput::new(pol_inputs_raw).unwrap();

        // Each sys crate compiles a copy of the same C++ runtime (loadCircuit,
        // get_size_of_witness, ...) under identical symbol names. When two
        // crates are linked into the same binary, the linker silently keeps one
        // definition of each symbol, so one circuit ends up using the
        // other's size constants — corrupting dat parsing and causing a SIGSEGV.
        // This test reproduces the conflict by calling generate_witness on both
        // circuits in the same binary.
        let _pol_witness = lbc_pol_sys::generate_witness(&pol_witness_input);

        let inputs_json_raw = std::fs::read_to_string(inputs::POQ.as_path()).unwrap();
        let inputs_json = PoqWitnessInput::new(inputs_json_raw).unwrap();
        let poq_result = lbc_poq_sys::generate_witness(&inputs_json);
        assert!(poq_result.is_ok());
    }
}
