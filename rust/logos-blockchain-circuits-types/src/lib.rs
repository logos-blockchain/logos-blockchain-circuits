//! Raw FFI types and Rust-safe wrappers for the witness generator C API.
//!
//! The [`ffi`] module contains `#[repr(C)]` types that mirror the C headers directly. The
//! [`native`] module re-exposes those through idiomatic Rust types that own their memory and
//! convert FFI return values into [`Result`]s.

pub mod native;
pub mod ffi;

pub use native::witness_input::WitnessInput;


pub mod inputs {
    use crate::native::Error;
    use crate::WitnessInput;

    pub trait CircuitDat {
        const DAT: &'static [u8];
    }

    // TODO: Remove in favour on native::WitnessInput.
    pub struct CircuitWitnessInput<'input, Dat> {
        inner: WitnessInput<'input>,
        _phantom: std::marker::PhantomData<Dat>
    }

    impl<'input, Dat: CircuitDat> CircuitWitnessInput<'input, Dat> {
        pub fn new(inputs_json: String) -> Result<Self, Error> {
            let inner = WitnessInput::new(Dat::DAT, inputs_json)?;
            Ok(Self { inner, _phantom: Default::default() })
        }
    }

    impl<'input, Dat> From<CircuitWitnessInput<'input, Dat>> for WitnessInput<'input> {
        fn from(value: CircuitWitnessInput<'input, Dat>) -> Self {
            value.inner
        }
    }

    impl<'input, Dat> From<WitnessInput<'input>> for CircuitWitnessInput<'input, Dat> {
        fn from(value: WitnessInput<'input>) -> Self {
            Self { inner: value, _phantom: Default::default() }
        }
    }
}
