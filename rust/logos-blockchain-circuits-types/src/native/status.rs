use std::ffi::CStr;
use thiserror::Error;
use crate::ffi::status::Code as FfiStatusCode;

pub type DynError = Box<dyn std::error::Error + Send + Sync>;
pub type Result<T> = std::result::Result<T, Error>;

#[derive(Debug, Error)]
pub enum Error {
    #[error("Invalid input")]
    InvalidInput,
    #[error("Out of memory")]
    OutOfMemory,
    #[error(transparent)]
    Other(#[from] DynError),
}

impl TryFrom<crate::ffi::Status> for () {
    type Error = Error;

    fn try_from(status: crate::ffi::Status) -> Result<()> {
        match status.code {
            FfiStatusCode::Ok => Ok(()),
            FfiStatusCode::DynError => {
                let message: Option<&CStr> =
                    if status.has_message() {
                        let status_message = unsafe {
                            CStr::from_ptr(status.message.as_ptr())
                        };
                        Some(status_message)
                    } else {
                        None
                    };
                let error_message = message
                    .map(|inner| DynError::from(inner.to_string_lossy().into_owned()))
                    .unwrap_or_else(|| DynError::from("Unknown error"));
                Err(error_message.into())
            },
            FfiStatusCode::InvalidInput => Err(Error::InvalidInput),
            FfiStatusCode::OutOfMemory => Err(Error::OutOfMemory),
        }
    }
}
