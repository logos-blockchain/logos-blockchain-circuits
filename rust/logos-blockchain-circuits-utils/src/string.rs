use std::path::Path;
use lbc_types::native::Error;

pub fn into_null_terminated_string(
    string: &str,
) -> Result<std::ffi::CString, Error> {
    std::ffi::CString::new(string)
        .map_err(|error| Error::InvalidInput(Some(format!("Could not convert string to CString: {error}"))))
}

pub fn path_as_null_terminated_string(
    path: &Path,
) -> Result<std::ffi::CString, Error> {
    let path = path.to_str().ok_or(Error::InvalidInput(Some(format!("Could not convert the path to a string: {}", path.display()))))?;
    into_null_terminated_string(path)
}
