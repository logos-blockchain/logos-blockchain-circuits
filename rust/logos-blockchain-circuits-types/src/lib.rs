//! Raw FFI types and Rust-safe wrappers for the witness generator C API.
//!
//! The [`ffi`] module contains `#[repr(C)]` types that mirror the C headers directly. The
//! [`native`] module re-exposes those through idiomatic Rust types that own their memory and
//! convert FFI return values into [`Result`]s.

pub mod native;
pub mod ffi;
