use std::path::PathBuf;

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

    fn fetch_library(version: &str, os: &str, arch: &str, lib_var_name: &str) -> Response<Body> {
        let url = build_artifact_url(version, os, arch);
        // We skip checksum verification intentionally.
        // Hardcoded hashes would protect against a silently replaced release asset but
        // require a two-step release (build → hash → commit → tag) which feels
        // overkill for a first-party library.
        ureq::get(&url).call().unwrap_or_else(|error| {
            panic!(
                "Failed to download a prebuilt library for {os}-{arch} v{version}: {error}. \
                 Set {lib_var_name} to point to a local build instead."
            )
        })
    }

    fn unpack_library(
        response: Response<Body>,
        circuit_name: &str,
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

        let unpacked_artifact_path = output_dir.join(build_artifact_name(version, os, arch));
        let unpacked_library_directory = unpacked_artifact_path.join(circuit_name);

        assert!(
            unpacked_library_directory.is_dir(),
            "Failed to find the unpacked library at {}",
            unpacked_library_directory.display()
        );

        unpacked_library_directory
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

    pub fn provision_library(circuit_name: &str, lib_var_name: &str) -> PathBuf {
        let version = env!("CARGO_PKG_VERSION");
        let os = std::env::var("CARGO_CFG_TARGET_OS").unwrap();
        let arch = std::env::var("CARGO_CFG_TARGET_ARCH").unwrap();

        let cache = get_cache_dir();
        // The tarball unpacks to a top-level `{artifact_name}/` dir, so the circuit
        // lives at `cache/{artifact_name}/{circuit_name}/`.
        let circuit_dir = cache
            .join(build_artifact_name(version, &os, &arch))
            .join(circuit_name);

        std::fs::create_dir_all(&cache).expect("Failed to create the cache directory.");

        // Since the circuits' libraries are all contained in the same single artifact,
        // each crate will try to download the same circuits.
        // To avoid redundant downloads, we use a lock to ensure that only one process
        // fetches the circuits while the others wait for it to complete and
        // then re-check the cache.
        let mut lock = get_lockfile(&cache);
        let _guard = lock.write().expect("Failed to acquire cache lock.");

        if circuit_dir.is_dir() {
            println!(
                "Found a cached {circuit_name} library at {}, reusing.",
                circuit_dir.display()
            );
            return circuit_dir;
        }

        println!(
            "No cached download found, downloading {circuit_name} v{version} for {os}-{arch}..."
        );
        let response = fetch_library(version, &os, &arch, lib_var_name);
        println!("Download complete, unpacking...");
        let lib_dir = unpack_library(response, circuit_name, version, &os, &arch, &cache);
        println!("Ready, {circuit_name} library at {}.", lib_dir.display());
        lib_dir
    }
}

mod env_vars {
    pub const BUNDLE_LIB_DIR: &str = "LBC_LIB_DIR";
}

pub fn build(circuit_name: &str, circuit_lib_dir_var: &str) {
    println!("cargo:rerun-if-env-changed={circuit_lib_dir_var}");
    println!("cargo:rerun-if-env-changed={}", env_vars::BUNDLE_LIB_DIR);
    println!("cargo:rerun-if-env-changed=CARGO_PKG_VERSION");
    println!("cargo:rerun-if-changed=Cargo.toml");
    println!("cargo:rerun-if-changed=build.rs");

    let circuit_lib_dir = std::env::var(circuit_lib_dir_var).map_or_else(
        |_| {
            #[cfg(not(feature = "prebuilt"))]
            panic!(
                "{circuit_lib_dir_var} is not set. Either:\n\
                 - Set {circuit_lib_dir_var} to point at a local build, or\n\
                 - Enable the `prebuilt` feature to download from GitHub Releases."
            );

            #[cfg(feature = "prebuilt")]
            {
                println!("Environment variable '{circuit_lib_dir_var}' is not set, falling back to prebuilt download");
                prebuilt::provision_library(circuit_name, circuit_lib_dir_var)
            }
        },
        |lib_dir| {
            println!("Environment variable '{circuit_lib_dir_var}' set, using local library at '{lib_dir}'");
            let lib_dir_path = PathBuf::from(lib_dir);
            assert!(
                lib_dir_path.is_dir(),
                "The library directory specified in '{circuit_lib_dir_var}' at {} does not exist.",
                lib_dir_path.display()
            );
            lib_dir_path
        },
    );

    let circuit_lib_dir_str = circuit_lib_dir
        .to_str()
        .expect("Failed to convert the library directory path to a string");

    let bundle_lib_dir = std::env::var(env_vars::BUNDLE_LIB_DIR).map_or_else(
        |_| {
            let default = circuit_lib_dir
                .parent()
                .expect("Failed to determine the circuit library directory's parent.")
                .join("lib");
            println!(
                "Environment variable '{}' is not set, falling back to sibling 'lib/' at '{}'.",
                env_vars::BUNDLE_LIB_DIR,
                default.display()
            );
            default
        },
        PathBuf::from,
    );

    let bundle_lib_dir_str = bundle_lib_dir
        .to_str()
        .expect("Failed to convert the bundle library directory path to a string");

    println!("cargo:rerun-if-changed={circuit_lib_dir_str}");
    println!("cargo:rerun-if-changed={bundle_lib_dir_str}");
    println!("cargo:rustc-env={circuit_lib_dir_var}={circuit_lib_dir_str}"); // Ensure it's always defined for downstream crates.
    println!("cargo:rustc-link-search=native={circuit_lib_dir_str}");
    println!("cargo:rustc-link-search=native={bundle_lib_dir_str}");
    println!("cargo:rustc-link-lib=static={circuit_name}");
    println!("cargo:rustc-link-lib=stdc++");
    println!("cargo:rustc-link-lib=static=gmp");
}
