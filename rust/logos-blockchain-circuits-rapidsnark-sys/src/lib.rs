use std::{path::PathBuf, sync::LazyLock};

#[cfg(target_os = "windows")]
const PROVER_BINARY: &str = "prover.exe";
#[cfg(not(target_os = "windows"))]
const PROVER_BINARY: &str = "prover";

#[cfg(target_os = "windows")]
const VERIFIER_BINARY: &str = "verifier.exe";
#[cfg(not(target_os = "windows"))]
const VERIFIER_BINARY: &str = "verifier";

fn lbc_root_dir() -> PathBuf {
    PathBuf::from(env!("LBC_ROOT_DIR"))
}

pub static PROVER: LazyLock<PathBuf> = LazyLock::new(|| {
    let path = lbc_root_dir().join(PROVER_BINARY);
    assert!(
        path.is_file(),
        "Rapidsnark prover not found: {}",
        path.display()
    );
    path
});

pub static VERIFIER: LazyLock<PathBuf> = LazyLock::new(|| {
    let path = lbc_root_dir().join(VERIFIER_BINARY);
    assert!(
        path.is_file(),
        "Rapidsnark verifier not found: {}",
        path.display()
    );
    path
});
