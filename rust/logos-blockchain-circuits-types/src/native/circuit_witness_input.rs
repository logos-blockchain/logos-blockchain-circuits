use std::{marker::PhantomData, ops::Deref};

use crate::native::{Error, WitnessInput};

pub trait Circuit<'dat> {
    const DAT: &'dat [u8];
}

pub struct CircuitWitnessInput<'dat, Dat> {
    inner: WitnessInput<'dat>,
    _phantom: PhantomData<Dat>,
}

impl<'dat, Dat> CircuitWitnessInput<'dat, Dat> {
    /// `dat` must be this circuit's witness generator data.
    pub fn new(dat: &'dat [u8], inputs_json: String) -> Result<Self, Error> {
        let inner = WitnessInput::new(dat, inputs_json)?;
        Ok(Self {
            inner,
            _phantom: PhantomData,
        })
    }
}

impl<'dat, Dat: Circuit<'dat>> CircuitWitnessInput<'dat, Dat> {
    /// Uses the circuit's embedded witness generator data.
    pub fn embedded(inputs_json: String) -> Result<Self, Error> {
        Self::new(Dat::DAT, inputs_json)
    }
}

impl<'dat, Dat> Deref for CircuitWitnessInput<'dat, Dat> {
    type Target = WitnessInput<'dat>;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}
