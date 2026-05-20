use std::{marker::PhantomData, ops::Deref};

use crate::native::{Error, WitnessInput};

pub trait CircuitDat<'dat> {
    const DAT: &'dat [u8];
}

pub struct CircuitWitnessInput<'dat, Dat> {
    inner: WitnessInput<'dat>,
    _phantom: PhantomData<Dat>,
}

impl<'dat, Dat: CircuitDat<'dat>> CircuitWitnessInput<'dat, Dat> {
    pub fn new(inputs_json: String) -> Result<Self, Error> {
        let inner = WitnessInput::new(Dat::DAT, inputs_json)?;
        Ok(Self {
            inner,
            _phantom: PhantomData,
        })
    }
}

impl<'dat, Dat> Deref for CircuitWitnessInput<'dat, Dat> {
    type Target = WitnessInput<'dat>;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}
