use std::path::PathBuf;

#[cfg(target_os = "windows")]
const PROVER_BINARY: &str = "prover.exe";
#[cfg(not(target_os = "windows"))]
const PROVER_BINARY: &str = "prover";

#[cfg(target_os = "windows")]
const VERIFIER_BINARY: &str = "verifier.exe";
#[cfg(not(target_os = "windows"))]
const VERIFIER_BINARY: &str = "verifier";

#[must_use]
fn lbc_root_dir() -> PathBuf {
    PathBuf::from(env!("LBC_ROOT_DIR"))
}

#[must_use]
pub fn prover() -> PathBuf {
    lbc_root_dir().join(PROVER_BINARY)
}

#[must_use]
pub fn verifier() -> PathBuf {
    lbc_root_dir().join(VERIFIER_BINARY)
}
