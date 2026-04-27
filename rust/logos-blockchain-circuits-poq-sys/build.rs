use std::path::{Path, PathBuf};
use ureq::Body;
use ureq::http::Response;

static CIRCUIT_NAME: &str = "poq";
static LIB_VAR_NAME: &str = "POQ_LIB_DIR";


fn get_artifact_name(version: &str, os: &str, arch: &str) -> String {
    format!("logos-blockchain-circuits-v{version}-{os}-{arch}")
}

fn get_artifact_url(version: &str, os: &str, arch: &str) -> String {
    let artifact = get_artifact_name(version, os, arch);
    let artifact_tar_gz = format!("{artifact}.tar.gz");
    format!(
        "https://github.com/logos-blockchain/logos-blockchain-circuits/releases/download/v{version}/{artifact_tar_gz}"
    )
}

fn fetch_library(version: &str, os: &str, arch: &str) -> Response<Body> {
    let url = get_artifact_url(version, os, arch);
    // TODO: Verify checksum.
    ureq::get(&url).call().unwrap_or_else(|error| {
        panic!(
            "Failed to download a prebuilt library for {os}-{arch} v{version}: {error}. \
                 Set {LIB_VAR_NAME} to point to a local build instead."
        )
    })
}

fn unpack_library(response: Response<Body>, version: &str, os: &str, arch: &str, output_dir: &Path) -> PathBuf {
    let gz_decoder = flate2::read::GzDecoder::new(response.into_body().into_reader());
    let mut archive = tar::Archive::new(gz_decoder);
    archive.unpack(output_dir).expect("Failed to unpack the downloaded archive.");

    let unpacked_artifact_path = output_dir.join(get_artifact_name(version, os, arch));
    let unpacked_library_directory = unpacked_artifact_path.join(CIRCUIT_NAME);

    if !unpacked_library_directory.exists() {
        panic!("Failed to find the unpacked library at {}.", unpacked_library_directory.display());
    }

    unpacked_library_directory
}

fn provision_library() -> PathBuf {
    let version = env!("CARGO_PKG_VERSION");
    let os = std::env::var("CARGO_CFG_TARGET_OS").unwrap();
    let arch = std::env::var("CARGO_CFG_TARGET_ARCH").unwrap();
    let out_dir = PathBuf::from(std::env::var("OUT_DIR").unwrap());

    let expected_library_directory = out_dir.join(get_artifact_name(version, &os, &arch)).join(CIRCUIT_NAME);
    if expected_library_directory.exists() {
        println!("Found an existing library at {}. Reusing it.", expected_library_directory.display());
        return expected_library_directory;
    }

    let response = fetch_library(version, &os, &arch);
    unpack_library(response, version, &os, &arch, &out_dir)
}

fn main() {
    println!("cargo:rerun-if-env-changed={LIB_VAR_NAME}");
    println!("cargo:rerun-if-env-changed=CARGO_PKG_VERSION");
    println!("cargo:rerun-if-changed=Cargo.toml");
    println!("cargo:rerun-if-changed=build.rs");

    let lib_dir = std::env::var(LIB_VAR_NAME).map(
        |lib_dir| {
            println!("Using a library directory from {LIB_VAR_NAME}: {lib_dir}");
            let lib_dir_path = PathBuf::from(lib_dir);
            if !lib_dir_path.exists() {
                panic!("The library directory specified in {LIB_VAR_NAME} at {} does not exist.", lib_dir_path.display());

            }
            lib_dir_path
        }
    ).unwrap_or_else(|_| {
        provision_library()
    });

    let lib_dir = lib_dir.to_str().expect("Failed to convert the library directory path to a string");
    println!("cargo:rustc-link-search=native={lib_dir}");
    println!("cargo:rustc-link-lib=static={CIRCUIT_NAME}");
}
