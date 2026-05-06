use std::ops::Deref;
use crate::native::{WitnessInput, Error};

pub trait CircuitDat<'dat> {
    const DAT: &'dat [u8];
}

pub struct CircuitWitnessInput<'dat, Dat> {
    inner: WitnessInput<'dat>,
    _phantom: std::marker::PhantomData<Dat>
}

impl<'dat, Dat: CircuitDat<'dat>> CircuitWitnessInput<'dat, Dat> {
    pub fn new(inputs_json: String) -> Result<Self, Error> {
        let inner = WitnessInput::new(Dat::DAT, inputs_json)?;
        Ok(Self { inner, _phantom: Default::default() })
    }
}

impl<'dat, Dat> Deref for CircuitWitnessInput<'dat, Dat> {
    type Target = WitnessInput<'dat>;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}
