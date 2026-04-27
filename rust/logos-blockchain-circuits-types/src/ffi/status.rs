use std::ffi::c_char;

/// Status codes for C API functions.
#[derive(PartialEq, Eq)] // Enables comparisons with named constants.
#[repr(transparent)]
pub struct Code(pub i32);

impl Code {
    pub const OK: Self = Self(0);
    pub const DYN_ERROR: Self = Self(1);
    pub const INVALID_INPUT: Self = Self(2);
    pub const OUT_OF_MEMORY: Self = Self(3);
}

impl Code {
    pub fn is_ok(&self) -> bool {
        self == &Self::OK
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
            code: Code::OK,
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
