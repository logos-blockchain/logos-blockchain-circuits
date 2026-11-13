/// Generates a `pub mod artifacts` containing the circuit compilation
/// artifacts.
///
/// The circuit artifacts are in `{LBC_ROOT_DIR}/<circuit_dir>/`.
/// The bytes are embedded from the build-time `LBC_ROOT_DIR`.
/// The paths use the run-time `LBC_ROOT_DIR` if it is set, or the build-time
/// one if it is not.
///
/// # Generated items
///
/// | Item                    | Description                            | Feature    |
/// |-------------------------|----------------------------------------|------------|
/// | `PROVING_KEY_PATH`      | Path to the proving key (`.zkey`)      | `paths`    |
/// | `PROVING_KEY`           | Proving key bytes                      | `embedded` |
/// | `VERIFICATION_KEY_PATH` | Path to the verification key (`.json`) | `paths`    |
/// | `VERIFICATION_KEY`      | Verification key bytes                 | `embedded` |
/// | `CIRCUIT_PATH`          | Path to the witness generator data     | `paths`    |
/// | `CIRCUIT`               | Witness generator data bytes           | `embedded` |
///
/// With the `paths` feature, the macro also generates a test that checks that
/// the 3 paths are files.
///
/// # Feature flags
///
/// The crate that calls this macro must declare the `embedded` and `paths`
/// features in its `Cargo.toml`.
/// The macro's `#[cfg(feature = "...")]` checks compile in that crate, so
/// features in this crate have no effect.
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
            #[cfg(feature = "paths")]
            use std::{path::PathBuf, sync::LazyLock};

            macro_rules! __circuit_path {
                ($file:literal) => {
                    LazyLock::new(|| $crate::lbc_root_dir!().join($circuit_dir).join($file))
                };
            }

            macro_rules! __circuit_file {
                ($file:literal) => {
                    // "LBC_ROOT_DIR" must stay in sync with the constant in `lbc-build`.
                    // env!() requires a literal so the name cannot be shared.
                    concat!(env!("LBC_ROOT_DIR"), "/", $circuit_dir, "/", $file)
                };
            }

            #[cfg(feature = "paths")]
            pub static PROVING_KEY_PATH: LazyLock<PathBuf> = __circuit_path!("proving_key.zkey");
            #[cfg(feature = "embedded")]
            pub static PROVING_KEY: &[u8] = include_bytes!(__circuit_file!("proving_key.zkey"));

            #[cfg(feature = "paths")]
            pub static VERIFICATION_KEY_PATH: LazyLock<PathBuf> =
                __circuit_path!("verification_key.json");
            #[cfg(feature = "embedded")]
            pub static VERIFICATION_KEY: &[u8] =
                include_bytes!(__circuit_file!("verification_key.json"));

            #[cfg(feature = "paths")]
            pub static CIRCUIT_PATH: LazyLock<PathBuf> = __circuit_path!("witness_generator.dat");
            #[cfg(feature = "embedded")]
            pub static CIRCUIT: &[u8] = include_bytes!(__circuit_file!("witness_generator.dat"));

            #[cfg(all(test, feature = "paths"))]
            mod tests {
                #[test]
                fn test_paths_exist() {
                    for path in [
                        &*super::PROVING_KEY_PATH,
                        &*super::VERIFICATION_KEY_PATH,
                        &*super::CIRCUIT_PATH,
                    ] {
                        assert!(path.is_file(), "{} is not a file.", path.display());
                    }
                }
            }
        }
    };
}
