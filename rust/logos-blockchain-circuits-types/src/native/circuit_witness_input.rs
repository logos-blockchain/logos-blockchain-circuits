use std::ops::Deref;
use crate::native::{WitnessInput, Error};

pub trait CircuitDat {
    const DAT: &'static [u8];
}

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

impl<'input, Dat> Deref for CircuitWitnessInput<'input, Dat> {
    type Target = WitnessInput<'input>;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}
