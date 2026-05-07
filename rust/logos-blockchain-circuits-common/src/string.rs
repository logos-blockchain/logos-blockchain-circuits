use lbc_types::native::Error;
use std::path::Path;

pub fn as_null_terminated_string(string: &str) -> Result<std::ffi::CString, Error> {
    std::ffi::CString::new(string).map_err(|error| {
        Error::InvalidInput(Some(format!(
            "Could not convert string to CString: {error}"
        )))
    })
}

pub fn path_as_null_terminated_string(path: &Path) -> Result<std::ffi::CString, Error> {
    let path = path.to_str().ok_or_else(|| {
        Error::InvalidInput(Some(format!(
            "Could not convert the path to a string: {}",
            path.display()
        )))
    })?;
    as_null_terminated_string(path)
}
