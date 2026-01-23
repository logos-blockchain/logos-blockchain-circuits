# Dockerfile for building Logos Blockchain Circuits
# This provides an isolated build environment to avoid polluting the host system
#
# Usage:
#   docker build -t logos-circuits-builder .
#   docker run --rm -v $(pwd):/workspace logos-circuits-builder [OPTIONS]
#
# Or use the helper script:
#   ./docker-build.sh [OPTIONS]

FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    libgmp-dev \
    libsodium-dev \
    nasm \
    curl \
    m4 \
    nlohmann-json3-dev \
    git \
    xxd \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install snarkjs globally
RUN npm install -g snarkjs@latest

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Clone and build Circom
RUN git clone https://github.com/iden3/circom.git /opt/circom \
    && cd /opt/circom \
    && RUSTFLAGS="-A dead_code" cargo build --release \
    && RUSTFLAGS="-A dead_code" cargo install --path circom

# Verify installations
RUN circom --version && node --version && npm --version

# Set up working directory
WORKDIR /workspace

# Create entrypoint script
RUN echo '#!/bin/bash\n\
set -e\n\
cd /workspace\n\
\n\
# Mark all directories as safe for git (needed for mounted volumes with different ownership)\n\
# This is safe in a container context where we control the environment\n\
git config --global --add safe.directory "*"\n\
\n\
# Initialize git submodules if needed (including nested submodules like rapidsnark/depends/*)\n\
if [ -f .gitmodules ]; then\n\
    git submodule update --init --recursive\n\
fi\n\
\n\
# Run the build script with provided arguments\n\
# Skip deps, circom, and snarkjs as they are already installed in the container\n\
exec ./scripts/build-local.sh --skip-deps --skip-circom --skip-snarkjs "$@"\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# Default: run full build (pass --help to see options)
CMD []