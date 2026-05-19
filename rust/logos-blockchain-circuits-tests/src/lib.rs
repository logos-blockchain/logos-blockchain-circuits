pub mod roots {
    use std::{
        path::{Path, PathBuf},
        sync::LazyLock,
    };

    pub static TESTS: LazyLock<PathBuf> =
        LazyLock::new(|| PathBuf::from(env!("CARGO_MANIFEST_DIR")));
    pub static REPOSITORY: LazyLock<&Path> =
        LazyLock::new(|| TESTS.parent().expect("Failed to find the repository root."));
    pub static POL: LazyLock<PathBuf> =
        LazyLock::new(|| REPOSITORY.join("logos-blockchain-circuits-pol-sys"));
    pub static POQ: LazyLock<PathBuf> =
        LazyLock::new(|| REPOSITORY.join("logos-blockchain-circuits-poq-sys"));
}

pub mod inputs {
    use std::{path::PathBuf, sync::LazyLock};

    use super::roots;

    pub static POL: LazyLock<PathBuf> = LazyLock::new(|| roots::POL.join("sample.input.json"));
    pub static POQ: LazyLock<PathBuf> = LazyLock::new(|| roots::POQ.join("sample.input.json"));
}
