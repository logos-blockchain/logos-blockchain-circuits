use std::ffi::CStr;
use std::fmt::Display;
use crate::ffi::status::Code as FfiStatusCode;

pub type Result<T> = std::result::Result<T, Error>;

/// Error returned when a witness generator call does not succeed.
#[derive(Debug)]
pub enum Error {
    InvalidInput(Option<String>),
    OutOfMemory(Option<String>),
    Other(Option<String>),
}

impl std::error::Error for Error {}

impl Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let (kind, message) = match self {
            Error::InvalidInput(msg) => ("Invalid input", msg),
            Error::OutOfMemory(msg) => ("Out of memory", msg),
            Error::Other(msg) => ("Other error", msg),
        };
        match message {
            Some(message) => write!(f, "{kind}: {message}"),
            None => write!(f, "{kind}"),
        }
    }
}

impl TryFrom<crate::ffi::Status> for () {
    type Error = Error;

    fn try_from(status: crate::ffi::Status) -> Result<()> {
        let message: Option<String> = if status.has_message() {
            let status_message = unsafe {
                CStr::from_ptr(status.message.as_ptr())
            };
            Some(status_message.to_string_lossy().into_owned())
        } else {
            None
        };

        match status.code {
            FfiStatusCode::OK => Ok(()),
            FfiStatusCode::DYN_ERROR => Err(Error::Other(message)),
            FfiStatusCode::INVALID_INPUT => Err(Error::InvalidInput(message)),
            FfiStatusCode::OUT_OF_MEMORY => Err(Error::OutOfMemory(message)),
            other => Err(Error::Other(Some(format!("Unknown status code: {}", other.0))))
        }
    }
}
