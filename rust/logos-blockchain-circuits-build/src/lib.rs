use std::path::{Path, PathBuf};

use ureq::Body;
use ureq::http::Response;

static REPO: &str = "logos-blockchain/logos-blockchain-circuits";
static ARTIFACT_PREFIX: &str = "logos-blockchain-circuits";

fn get_artifact_name(version: &str, os: &str, arch: &str) -> String {
    format!("{ARTIFACT_PREFIX}-v{version}-{os}-{arch}")
}

fn get_artifact_url(version: &str, os: &str, arch: &str) -> String {
    let artifact = get_artifact_name(version, os, arch);
    let artifact_tar_gz = format!("{artifact}.tar.gz");
    format!("https://github.com/{REPO}/releases/download/v{version}/{artifact_tar_gz}")
}

fn fetch_library(version: &str, os: &str, arch: &str, lib_var_name: &str) -> Response<Body> {
    let url = get_artifact_url(version, os, arch);
    // We skip checksum verification intentionally.
    // Hardcoded hashes would protect against a silently replaced release asset, but require a
    // two-step release (build → hash → commit → tag) which feels overkill for a first-party
    // library.
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

    let unpacked_artifact_path = output_dir.join(get_artifact_name(version, os, arch));
    let unpacked_library_directory = unpacked_artifact_path.join(circuit_name);

    assert!(
        unpacked_library_directory.is_dir(),
        "Failed to find the unpacked library at {}",
        unpacked_library_directory.display()
    );

    unpacked_library_directory
}

fn provision_library(circuit_name: &str, lib_var_name: &str) -> PathBuf {
    let version = env!("CARGO_PKG_VERSION");
    let os = std::env::var("CARGO_CFG_TARGET_OS").unwrap();
    let arch = std::env::var("CARGO_CFG_TARGET_ARCH").unwrap();
    let out_dir = PathBuf::from(std::env::var("OUT_DIR").unwrap());

    let expected_library_directory = out_dir
        .join(get_artifact_name(version, &os, &arch))
        .join(circuit_name);
    if expected_library_directory.is_dir() {
        println!(
            "Found an existing library at {}. Reusing it.",
            expected_library_directory.display()
        );
        return expected_library_directory;
    }

    let response = fetch_library(version, &os, &arch, lib_var_name);
    unpack_library(response, circuit_name, version, &os, &arch, &out_dir)
}

pub fn build(circuit_name: &str, lib_var_name: &str) {
    println!("cargo:rerun-if-env-changed={lib_var_name}");
    println!("cargo:rerun-if-env-changed=CARGO_PKG_VERSION");
    println!("cargo:rerun-if-changed=Cargo.toml");
    println!("cargo:rerun-if-changed=build.rs");

    let lib_dir = std::env::var(lib_var_name).map_or_else(
        |_| provision_library(circuit_name, lib_var_name),
        |lib_dir| {
            println!("Using a library directory from {lib_var_name}: {lib_dir}");
            let lib_dir_path = PathBuf::from(lib_dir);
            assert!(
                lib_dir_path.is_dir(),
                "The library directory specified in {lib_var_name} at {} does not exist.",
                lib_dir_path.display()
            );
            lib_dir_path
        },
    );

    let lib_dir = lib_dir
        .to_str()
        .expect("Failed to convert the library directory path to a string");
    println!("cargo:rustc-env={lib_var_name}={lib_dir}");
    println!("cargo:rustc-link-search=native={lib_dir}");
    println!("cargo:rustc-link-lib=static={circuit_name}");
    println!("cargo:rustc-link-lib=stdc++");
    println!("cargo:rustc-link-lib=gmp");
}
