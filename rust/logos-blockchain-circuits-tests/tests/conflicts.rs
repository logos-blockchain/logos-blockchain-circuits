#[cfg(all(test, feature = "embed-circuits"))]
mod tests {
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
        let poq_witness_input = lbc_poq_sys::PoqWitnessInput::new(inputs_json_raw).unwrap();
        let poq_witness_result = lbc_poq_sys::generate_witness(&poq_witness_input);
        assert!(poq_witness_result.is_ok());
    }

    #[test]
    fn test_concurrent_poq_calls() {
        let inputs_json_raw = std::fs::read_to_string(inputs::POQ.as_path()).unwrap();

        let handles: Vec<_> = (0..4)
            .map(|_| {
                let json = inputs_json_raw.clone();
                std::thread::spawn(move || {
                    let poq_witness_input = lbc_poq_sys::PoqWitnessInput::new(json)
                        .expect("PoqWitnessInput::new failed.");
                    lbc_poq_sys::generate_witness(&poq_witness_input)
                })
            })
            .collect();

        for handle in handles {
            assert!(handle.join().unwrap().is_ok());
        }
    }
}
