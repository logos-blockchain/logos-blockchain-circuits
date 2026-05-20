#!/usr/bin/env python3
# Updates circuits-nix-hashes.json with new platform hashes, overwriting any existing entry for the version.

import os, json
from packaging.version import Version

PLATFORM_X86_64_LINUX = "x86_64-linux"
PLATFORM_AARCH64_LINUX = "aarch64-linux"
PLATFORM_AARCH64_DARWIN = "aarch64-darwin"
PLATFORM_X86_64_WINDOWS = "x86_64-windows"

ENV_VAR_VERSION = "VERSION"
ENV_VAR_CIRCUITS_NIX_HASHES_FILE = "CIRCUITS_NIX_HASHES_FILE"
ENV_VAR_CIRCUIT_HASH_LINUX_X86_64 = "CIRCUIT_HASH_LINUX_X86_64"
ENV_VAR_CIRCUIT_HASH_LINUX_AARCH64 = "CIRCUIT_HASH_LINUX_AARCH64"
ENV_VAR_CIRCUIT_HASH_DARWIN_AARCH64 = "CIRCUIT_HASH_DARWIN_AARCH64"
ENV_VAR_CIRCUIT_HASH_WINDOWS_X86_64 = "CIRCUIT_HASH_WINDOWS_X86_64"

REQUIRED_ENV_VARS_KEYS = [
    ENV_VAR_VERSION,
    ENV_VAR_CIRCUITS_NIX_HASHES_FILE,
    ENV_VAR_CIRCUIT_HASH_LINUX_X86_64,
    ENV_VAR_CIRCUIT_HASH_LINUX_AARCH64,
    ENV_VAR_CIRCUIT_HASH_DARWIN_AARCH64,
    ENV_VAR_CIRCUIT_HASH_WINDOWS_X86_64,
]

REQUIRED_ENV_VARS = {var: os.getenv(var) for var in REQUIRED_ENV_VARS_KEYS}

missing_env_vars = [f"  - {key}" for key, value in REQUIRED_ENV_VARS.items() if value is None]
if missing_env_vars:
    missing_env_vars_message = "\n".join(missing_env_vars)
    error_message = f"Missing required env vars:\n{missing_env_vars_message}"
    raise SystemExit(error_message)

filepath = REQUIRED_ENV_VARS[ENV_VAR_CIRCUITS_NIX_HASHES_FILE]
version = REQUIRED_ENV_VARS[ENV_VAR_VERSION].lstrip("v")
x86_64_linux = REQUIRED_ENV_VARS[ENV_VAR_CIRCUIT_HASH_LINUX_X86_64]
aarch64_linux = REQUIRED_ENV_VARS[ENV_VAR_CIRCUIT_HASH_LINUX_AARCH64]
aarch64_darwin = REQUIRED_ENV_VARS[ENV_VAR_CIRCUIT_HASH_DARWIN_AARCH64]
x86_64_windows = REQUIRED_ENV_VARS[ENV_VAR_CIRCUIT_HASH_WINDOWS_X86_64]

with open(filepath) as file:
    data = json.load(file)

data[version] = {
    PLATFORM_X86_64_LINUX: x86_64_linux,
    PLATFORM_AARCH64_LINUX: aarch64_linux,
    PLATFORM_AARCH64_DARWIN: aarch64_darwin,
    PLATFORM_X86_64_WINDOWS: x86_64_windows,
}

with open(filepath, "w") as file:
    json.dump(dict(sorted(data.items(), key=lambda x: Version(x[0]))), file, indent=4, sort_keys=True)
    file.write("\n")

print(f"Updated {filepath} with version {version}.")
