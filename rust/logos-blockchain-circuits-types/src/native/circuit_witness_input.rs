use std::{marker::PhantomData, ops::Deref};

use crate::native::{Error, WitnessInput};

/// A circuit whose witness generator data is embedded in its `-sys` crate.
pub trait EmbeddedCircuit<'dat> {
    const DAT: &'dat [u8];
}

pub struct CircuitWitnessInput<'dat, Circuit> {
    inner: WitnessInput<'dat>,
    _phantom: PhantomData<Circuit>,
}

impl<'dat, Circuit> CircuitWitnessInput<'dat, Circuit> {
    /// Creates a witness input from the circuit's witness generator data and
    /// inputs.
    ///
    /// # Arguments
    ///
    /// - `dat`: the witness generator data of this circuit, e.g. the
    ///   `artifacts::CIRCUIT` of its `-sys` crate.
    /// - `inputs_json`: the circuit inputs, as a JSON object.
    ///
    /// # Errors
    ///
    /// Returns [`Error::InvalidInput`] if `inputs_json` contains a NUL byte.
    pub fn new(dat: &'dat [u8], inputs_json: String) -> Result<Self, Error> {
        let inner = WitnessInput::new(dat, inputs_json)?;
        Ok(Self {
            inner,
            _phantom: PhantomData,
        })
    }
}

impl<'dat, Circuit: EmbeddedCircuit<'dat>> CircuitWitnessInput<'dat, Circuit> {
    /// Creates a witness input with the circuit's embedded witness generator
    /// data.
    ///
    /// Requires the `embedded` feature of the circuit's `-sys` crate, on by
    /// default.
    ///
    /// # Arguments
    ///
    /// - `inputs_json`: the circuit inputs, as a JSON object.
    ///
    /// # Errors
    ///
    /// Returns [`Error::InvalidInput`] if `inputs_json` contains a NUL byte.
    pub fn embedded(inputs_json: String) -> Result<Self, Error> {
        Self::new(Circuit::DAT, inputs_json)
    }
}

impl<'dat, Circuit> Deref for CircuitWitnessInput<'dat, Circuit> {
    type Target = WitnessInput<'dat>;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}
