use std::path::PathBuf;

// Canonical definition of the env var name. Also hardcoded as a literal in
// `lbc-common`'s `circuit_artifacts!` macro (env!() requires a literal).
const LBC_ROOT_DIR: &str = "LBC_ROOT_DIR";

#[cfg(feature = "prebuilt")]
mod prebuilt {
    use std::{
        collections::BTreeMap,
        fs::File,
        path::{Path, PathBuf},
    };

    use base64::{Engine as _, engine::general_purpose::STANDARD};
    use sha2::{Digest as _, Sha256};

    static REPO: &str = "logos-blockchain/logos-blockchain-circuits";
    static ARTIFACT_PREFIX: &str = "logos-blockchain-circuits";

    /// The SHA-256 of each release archive, as a Nix SRI hash
    /// (`sha256-<base64>`), by version and Nix system. CI adds a release's
    /// hashes once it has built the archives, in the commit that the
    /// release tag then points to.
    static ARCHIVE_HASHES: &str = include_str!("../circuits-nix-hashes.json");

    /// The file in an artifact directory that holds the hash of the archive it
    /// was unpacked from. It's written once unpacking completes, so a
    /// directory without it was left by an interrupted unpack, or by a
    /// version of this crate that didn't verify downloads.
    static ARCHIVE_HASH_FILE: &str = ".archive-sha256";

    fn build_artifact_name(version: &str, os: &str, arch: &str) -> String {
        format!("{ARTIFACT_PREFIX}-v{version}-{os}-{arch}")
    }

    fn build_artifact_url(version: &str, os: &str, arch: &str) -> String {
        let artifact = build_artifact_name(version, os, arch);
        let artifact_tar_gz = format!("{artifact}.tar.gz");
        format!("https://github.com/{REPO}/releases/download/v{version}/{artifact_tar_gz}")
    }

    /// The hash that the release archive for this version and platform must
    /// have.
    fn expected_archive_hash(version: &str, os: &str, arch: &str) -> String {
        // Nix calls macOS `darwin`.
        let nix_os = if os == "macos" { "darwin" } else { os };
        let system = format!("{arch}-{nix_os}");
        let hashes: BTreeMap<String, BTreeMap<String, String>> =
            serde_json::from_str(ARCHIVE_HASHES)
                .expect("Failed to parse `circuits-nix-hashes.json`.");
        hashes
            .get(version)
            .and_then(|systems| systems.get(&system))
            .cloned()
            .unwrap_or_else(|| {
                panic!(
                    "`circuits-nix-hashes.json` has no hash for the {system} archive of v{version}. \
                     CI adds it once the release is built, in the commit that the release tag \
                     points to. Depend on that commit, or set {ENV_VAR} to point to a local build.",
                    ENV_VAR = super::LBC_ROOT_DIR
                )
            })
    }

    fn download_archive(version: &str, os: &str, arch: &str, destination: &Path) {
        let url = build_artifact_url(version, os, arch);
        let response = ureq::get(&url).call().unwrap_or_else(|error| {
            panic!(
                "Failed to download a prebuilt artifact for {os}-{arch} v{version}: {error}. \
                 Set {ENV_VAR} to point to a local build instead.",
                ENV_VAR = super::LBC_ROOT_DIR
            )
        });
        let mut file = File::create(destination).expect("Failed to create the archive file.");
        std::io::copy(&mut response.into_body().into_reader(), &mut file)
            .expect("Failed to download the archive.");
    }

    /// The hash of the archive at `path`, in the format of
    /// `circuits-nix-hashes.json`.
    fn archive_hash(path: &Path) -> String {
        let mut file = File::open(path).expect("Failed to open the downloaded archive.");
        let mut hasher = Sha256::new();
        std::io::copy(&mut file, &mut hasher).expect("Failed to read the downloaded archive.");
        format!("sha256-{}", STANDARD.encode(hasher.finalize()))
    }

    fn unpack_archive(archive: &Path, output_dir: &Path) {
        let file = File::open(archive).expect("Failed to open the downloaded archive.");
        tar::Archive::new(flate2::read::GzDecoder::new(file))
            .unpack(output_dir)
            .expect("Failed to unpack the downloaded archive.");
    }

    /// Produce a lockfile for the given directory
    fn get_lockfile(directory: &Path) -> fd_lock::RwLock<File> {
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
        let expected_hash = expected_archive_hash(version, &os, &arch);

        let cache = get_cache_dir();
        let artifact_name = build_artifact_name(version, &os, &arch);
        let artifact_root = cache.join(&artifact_name);
        let archive_hash_file = artifact_root.join(ARCHIVE_HASH_FILE);

        std::fs::create_dir_all(&cache).expect("Failed to create the cache directory.");

        // Since the circuits' libraries are all contained in the same single artifact,
        // each crate will try to download the same artifact.
        // To avoid redundant downloads, we use a lock to ensure that only one process
        // fetches the artifact while the others wait for it to complete and
        // then re-check the cache.
        let mut lock = get_lockfile(&cache);
        let _guard = lock.write().expect("Failed to acquire cache lock.");

        if std::fs::read_to_string(&archive_hash_file).is_ok_and(|hash| hash == expected_hash) {
            println!(
                "Found a cached artifact at {}, reusing.",
                artifact_root.display()
            );
            return artifact_root;
        }

        if artifact_root.exists() {
            println!(
                "Removing the cached artifact at {}, which wasn't unpacked from a verified archive.",
                artifact_root.display()
            );
            std::fs::remove_dir_all(&artifact_root).expect("Failed to remove the cached artifact.");
        }

        println!("No verified cached artifact found, downloading v{version} for {os}-{arch}...");
        let archive = cache.join(format!("{artifact_name}.tar.gz"));
        download_archive(version, &os, &arch, &archive);

        let hash = archive_hash(&archive);
        if hash != expected_hash {
            std::fs::remove_file(&archive).expect("Failed to remove the downloaded archive.");
            panic!(
                "The downloaded archive for {os}-{arch} v{version} has the hash {hash}, but \
                 `circuits-nix-hashes.json` expects {expected_hash}."
            );
        }

        println!("Download complete and verified, unpacking...");
        unpack_archive(&archive, &cache);
        std::fs::remove_file(&archive).expect("Failed to remove the downloaded archive.");

        assert!(
            artifact_root.is_dir(),
            "Failed to find the unpacked artifact directory at {}.",
            artifact_root.display()
        );
        std::fs::write(&archive_hash_file, &expected_hash)
            .expect("Failed to record the hash of the unpacked archive.");

        println!("Ready, artifact at {}.", artifact_root.display());
        artifact_root
    }
}

/// Resolves the circuits root directory, either from the environment variable
/// or by downloading a prebuilt version.
///
/// If called more than once per build script (e.g. `build_circuit` +
/// `build_rapidsnark`), `cargo:rustc-env=LBC_ROOT_DIR` is emitted twice. Cargo
/// takes last-wins for duplicate keys, but this is safe here since both calls
/// resolve to the same path.
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

    let extension = if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        ".exe"
    } else {
        ""
    };
    for binary in ["prover", "verifier"] {
        let path = root.join(format!("{binary}{extension}"));
        println!("cargo:rerun-if-changed={}", path.display());
    }
}
