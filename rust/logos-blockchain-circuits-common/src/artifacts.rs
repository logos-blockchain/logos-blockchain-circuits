/// Generates a `pub mod artifacts` containing the circuit compilation
/// artifacts.
///
/// The artifacts are loaded from `LBC_ROOT_DIR/{circuit_dir}/`, set by the
/// crate's build script.
///
/// # Generated items
///
/// | Item                    | Description                             |
/// |-------------------------|-----------------------------------------|
/// | `PROVING_KEY_PATH`      | Path to the proving key (`.zkey`)       |
/// | `PROVING_KEY`           | Proving key bytes                       |
/// | `VERIFICATION_KEY_PATH` | Path to the verification key (`.json`)  |
/// | `VERIFICATION_KEY`      | Verification key bytes                  |
/// | `CIRCUIT_DAT_PATH`      | Path to the witness generator data      |
/// | `CIRCUIT_DAT`           | Witness generator data bytes            |
///
/// # Example
///
/// ```ignore
/// lbc_common::circuit_artifacts!("poq"); // uses {LBC_ROOT_DIR}/poq/
/// ```
#[macro_export]
macro_rules! circuit_artifacts {
    ($circuit_dir:literal) => {
        pub mod artifacts {
            macro_rules! __circuit_file {
                ($file:literal) => {
                    // "LBC_ROOT_DIR" must stay in sync with the constant in `lbc-build`.
                    // env!() requires a literal so the name cannot be shared.
                    concat!(env!("LBC_ROOT_DIR"), "/", $circuit_dir, "/", $file)
                };
            }

            pub const PROVING_KEY_PATH: &str = __circuit_file!("proving_key.zkey");
            pub static PROVING_KEY: &[u8] = include_bytes!(__circuit_file!("proving_key.zkey"));

            pub const VERIFICATION_KEY_PATH: &str = __circuit_file!("verification_key.json");
            pub static VERIFICATION_KEY: &[u8] =
                include_bytes!(__circuit_file!("verification_key.json"));

            pub const CIRCUIT_DAT_PATH: &str = __circuit_file!("witness_generator.dat");
            pub static CIRCUIT_DAT: &[u8] =
                include_bytes!(__circuit_file!("witness_generator.dat"));
        }
    };
}
