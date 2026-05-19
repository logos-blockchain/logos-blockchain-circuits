pub mod roots {
    use std::path::{Path, PathBuf};
    use std::sync::LazyLock;

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
    use super::roots;
    use std::path::PathBuf;
    use std::sync::LazyLock;

    pub static POL: LazyLock<PathBuf> = LazyLock::new(|| roots::POL.join("sample.input.json"));
    pub static POQ: LazyLock<PathBuf> = LazyLock::new(|| roots::POQ.join("sample.input.json"));
}
