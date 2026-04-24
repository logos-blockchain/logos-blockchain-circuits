use std::ffi::c_char;

/// Status codes for C API functions.
#[repr(C)]
pub enum Code {
    Ok = 0,
    DynError = 1,
    InvalidInput = 2,
    OutOfMemory = 3,
}

impl Code {
    pub fn is_ok(&self) -> bool {
        matches!(self, Code::Ok)
    }

    pub fn is_error(&self) -> bool {
        !self.is_ok()
    }
}

/// Status reporting structure for C API functions.
#[repr(C)]
pub struct Status {
    pub code: Code,
    pub message: [c_char; 256],
}

impl Status {
    pub fn ok() -> Self {
        Status {
            code: Code::Ok,
            message: [0; 256],
        }
    }

    pub fn is_ok(&self) -> bool {
        self.code.is_ok()
    }

    pub fn is_error(&self) -> bool {
        self.code.is_error()
    }

    pub fn has_message(&self) -> bool {
        self.message[0] != 0
    }
}
