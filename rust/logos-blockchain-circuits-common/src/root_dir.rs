use std::path::PathBuf;

/// Returns the circuits root directory, with the calling crate's build-time
/// `LBC_ROOT_DIR` as the fallback.
#[macro_export]
macro_rules! lbc_root_dir {
    () => {
        $crate::root_dir::lbc_root_dir(env!("LBC_ROOT_DIR"))
    };
}

/// Returns `LBC_ROOT_DIR` at run time if it is set, or `build_root_dir` if it
/// is not.
///
/// `lbc_root_dir!` passes `env!("LBC_ROOT_DIR")` here, so the value comes from
/// the calling crate's build script.
pub fn lbc_root_dir(build_root_dir: &str) -> PathBuf {
    std::env::var_os("LBC_ROOT_DIR").map_or_else(|| PathBuf::from(build_root_dir), PathBuf::from)
}
