use std::path::PathBuf;

// Canonical definition of the env var name. Also hardcoded as a literal in
// `lbc-common`'s `circuit_artifacts!` macro (env!() requires a literal).
const LBC_ROOT_DIR: &str = "LBC_ROOT_DIR";

#[cfg(feature = "prebuilt")]
mod prebuilt {
    use std::path::{Path, PathBuf};

    use ureq::{Body, http::Response};

    static REPO: &str = "logos-blockchain/logos-blockchain-circuits";
    static ARTIFACT_PREFIX: &str = "logos-blockchain-circuits";

    fn build_artifact_name(version: &str, os: &str, arch: &str) -> String {
        format!("{ARTIFACT_PREFIX}-v{version}-{os}-{arch}")
    }

    fn build_artifact_url(version: &str, os: &str, arch: &str) -> String {
        let artifact = build_artifact_name(version, os, arch);
        let artifact_tar_gz = format!("{artifact}.tar.gz");
        format!("https://github.com/{REPO}/releases/download/v{version}/{artifact_tar_gz}")
    }

    fn fetch_artifact(version: &str, os: &str, arch: &str) -> Response<Body> {
        let url = build_artifact_url(version, os, arch);
        // We skip checksum verification intentionally.
        // Hardcoded hashes would protect against a silently replaced release asset but
        // require a two-step release (build → hash → commit → tag) which feels
        // overkill for a first-party library.
        ureq::get(&url).call().unwrap_or_else(|error| {
            panic!(
                "Failed to download a prebuilt artifact for {os}-{arch} v{version}: {error}. \
                 Set {ENV_VAR} to point to a local build instead.",
                ENV_VAR = super::LBC_ROOT_DIR
            )
        })
    }

    fn unpack_artifact(
        response: Response<Body>,
        version: &str,
        os: &str,
        arch: &str,
        output_dir: &Path,
    ) -> PathBuf {
        let gz_decoder = flate2::read::GzDecoder::new(response.into_body().into_reader());
        let mut archive = tar::Archive::new(gz_decoder);
        archive
            .unpack(output_dir)
            .expect("Failed to unpack the downloaded archive.");

        let artifact_root = output_dir.join(build_artifact_name(version, os, arch));

        assert!(
            artifact_root.is_dir(),
            "Failed to find the unpacked artifact directory at {}.",
            artifact_root.display()
        );

        artifact_root
    }

    /// Produce a lockfile for the given directory
    fn get_lockfile(directory: &Path) -> fd_lock::RwLock<std::fs::File> {
        let file = std::fs::OpenOptions::new()
            .create(true)
            .truncate(false)
            .write(true)
            .open(directory.join(".lock"))
            .expect("Failed to open the cache lock file.");
        fd_lock::RwLock::new(file)
    }

    fn get_cache_dir() -> PathBuf {
        dirs::cache_dir()
            .expect("Could not determine the cache directory for this platform.")
            .join("logos")
            .join("blockchain")
    }

    pub fn provision_artifact() -> PathBuf {
        let version = env!("CARGO_PKG_VERSION");
        let os = std::env::var("CARGO_CFG_TARGET_OS").unwrap();
        let arch = std::env::var("CARGO_CFG_TARGET_ARCH").unwrap();

        let cache = get_cache_dir();
        let artifact_root = cache.join(build_artifact_name(version, &os, &arch));

        std::fs::create_dir_all(&cache).expect("Failed to create the cache directory.");

        // Since the circuits' libraries are all contained in the same single artifact,
        // each crate will try to download the same artifact.
        // To avoid redundant downloads, we use a lock to ensure that only one process
        // fetches the artifact while the others wait for it to complete and
        // then re-check the cache.
        let mut lock = get_lockfile(&cache);
        let _guard = lock.write().expect("Failed to acquire cache lock.");

        if artifact_root.is_dir() {
            println!(
                "Found a cached artifact at {}, reusing.",
                artifact_root.display()
            );
            return artifact_root;
        }

        println!("No cached download found, downloading v{version} for {os}-{arch}...");
        let response = fetch_artifact(version, &os, &arch);
        println!("Download complete, unpacking...");
        let root = unpack_artifact(response, version, &os, &arch, &cache);
        println!("Ready, artifact at {}.", root.display());
        root
    }
}

fn resolve_root() -> PathBuf {
    println!("cargo:rerun-if-env-changed={LBC_ROOT_DIR}");
    println!("cargo:rerun-if-env-changed=CARGO_PKG_VERSION");
    println!("cargo:rerun-if-changed=Cargo.toml");
    println!("cargo:rerun-if-changed=build.rs");

    let root = std::env::var(LBC_ROOT_DIR).map_or_else(
        |_| {
            #[cfg(not(feature = "prebuilt"))]
            panic!(
                "{LBC_ROOT_DIR} is not set. Either:\n\
                 - Set {LBC_ROOT_DIR} to point at a local build, or\n\
                 - Enable the `prebuilt` feature to download from GitHub Releases."
            );

            #[cfg(feature = "prebuilt")]
            {
                println!(
                    "Environment variable '{LBC_ROOT_DIR}' is not set, falling back to prebuilt download"
                );
                prebuilt::provision_artifact()
            }
        },
        |dir| {
            println!("Environment variable '{LBC_ROOT_DIR}' set, using local artifact at '{dir}'");
            let dir_path = PathBuf::from(dir);
            assert!(
                dir_path.is_dir(),
                "The root directory specified in '{LBC_ROOT_DIR}' at {} does not exist.",
                dir_path.display()
            );
            dir_path
        },
    );

    let root_str = root
        .to_str()
        .expect("Failed to convert the root directory path to a string");

    println!("cargo:rustc-env={LBC_ROOT_DIR}={root_str}");

    root
}

pub fn build_circuit(circuit_name: &str) {
    let root = resolve_root();

    let circuit_dir = root.join(circuit_name);
    let circuit_dir_str = circuit_dir
        .to_str()
        .expect("Failed to convert the circuit directory path to a string");

    let lib_dir = root.join("lib");
    let lib_dir_str = lib_dir
        .to_str()
        .expect("Failed to convert the lib directory path to a string");

    println!("cargo:rerun-if-changed={circuit_dir_str}");
    println!("cargo:rerun-if-changed={lib_dir_str}");
    println!("cargo:rustc-link-search=native={circuit_dir_str}");
    println!("cargo:rustc-link-search=native={lib_dir_str}");
    println!("cargo:rustc-link-lib=static={circuit_name}");
    let cpp_lib = std::env::var("CARGO_CFG_TARGET_OS").map_or_else(
        |_| "stdc++",
        |os| if os == "macos" { "c++" } else { "stdc++" },
    );
    println!("cargo:rustc-link-lib={cpp_lib}");
    println!("cargo:rustc-link-lib=static=gmp");
}

pub fn build_rapidsnark() {
    let root = resolve_root();

    for binary in ["prover", "verifier"] {
        let path = root.join(binary);
        println!("cargo:rerun-if-changed={}", path.display());
    }
}
