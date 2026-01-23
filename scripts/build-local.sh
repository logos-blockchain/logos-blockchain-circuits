#!/usr/bin/env bash
#
# Local Build Script for Logos Blockchain Circuits
# This script replicates the GitHub Actions workflow for local execution on Linux.
#
# Usage:
#   ./build-local.sh [OPTIONS]
#
# Options:
#   --version VERSION   Set the version (default: v0.0.0-local)
#   --skip-deps         Skip installing system dependencies
#   --skip-circom       Skip Circom installation (assumes circom is in PATH)
#   --skip-snarkjs      Skip snarkjs installation (assumes snarkjs is in PATH)
#   --skip-ptau         Skip Powers of Tau download (assumes file exists)
#   --skip-proving-keys Skip proving key generation (assumes they exist)
#   --skip-prover       Skip prover/verifier compilation
#   --skip-witness      Skip witness generator compilation
#   --circuit CIRCUIT   Build only specified circuit (pol, poq, zksign, poc)
#   --clean             Clean all build artifacts before building
#   --help              Show this help message
#
# Requirements:
#   - Linux x86_64
#   - Root access (for installing dependencies) or pre-installed dependencies
#   - Internet connection (for downloading dependencies)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default configuration
VERSION="v0.0.0-local"
OS="linux"
# Auto-detect architecture
MACHINE_ARCH="$(uname -m)"
case "$MACHINE_ARCH" in
    x86_64|amd64)
        ARCH="x86_64"
        ;;
    aarch64|arm64)
        ARCH="aarch64"
        ;;
    *)
        ARCH="$MACHINE_ARCH"
        ;;
esac
PTAU_URL="https://storage.googleapis.com/zkevm/ptau/powersOfTau28_hez_final_17.ptau"
PTAU_FILE="powersOfTau28_hez_final_17.ptau"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Flags
SKIP_DEPS=false
SKIP_CIRCOM=false
SKIP_SNARKJS=false
SKIP_PTAU=false
SKIP_PROVING_KEYS=false
SKIP_PROVER=false
SKIP_WITNESS=false
CLEAN=false
SINGLE_CIRCUIT=""

# Circuit definitions
declare -A CIRCUITS=(
    ["pol"]="mantle/pol.circom:pol:PoL"
    ["poq"]="blend/poq.circom:poq:PoQ"
    ["zksign"]="mantle/signature.circom:signature:ZKSign"
    ["poc"]="mantle/poc.circom:poc:PoC"
)

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                VERSION="$2"
                shift 2
                ;;
            --skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            --skip-circom)
                SKIP_CIRCOM=true
                shift
                ;;
            --skip-snarkjs)
                SKIP_SNARKJS=true
                shift
                ;;
            --skip-ptau)
                SKIP_PTAU=true
                shift
                ;;
            --skip-proving-keys)
                SKIP_PROVING_KEYS=true
                shift
                ;;
            --skip-prover)
                SKIP_PROVER=true
                shift
                ;;
            --skip-witness)
                SKIP_WITNESS=true
                shift
                ;;
            --circuit)
                SINGLE_CIRCUIT="$2"
                shift 2
                ;;
            --clean)
                CLEAN=true
                shift
                ;;
            --help)
                head -n 25 "$0" | tail -n +2 | sed 's/^# //' | sed 's/^#//'
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Clean build artifacts
clean_artifacts() {
    log_info "Cleaning build artifacts..."
    
    # Clean circom build directories
    rm -rf "$PROJECT_ROOT/circom/" 2>/dev/null || true
    
    # Clean rapidsnark build
    if [[ -d "$PROJECT_ROOT/rapidsnark" ]]; then
        cd "$PROJECT_ROOT/rapidsnark"
        make clean 2>/dev/null || true
        cd "$PROJECT_ROOT"
    fi
    
    # Clean circuit build directories
    for circuit_key in "${!CIRCUITS[@]}"; do
        IFS=':' read -r circuit_path circuit_name display_name <<< "${CIRCUITS[$circuit_key]}"
        circuit_dir=$(dirname "$circuit_path")
        circuit_filestem=$(basename "$circuit_path" .circom)
        
        rm -rf "${circuit_dir}/${circuit_filestem}_cpp" 2>/dev/null || true
        rm -f "${circuit_dir}/${circuit_filestem}.r1cs" 2>/dev/null || true
        rm -f "${circuit_dir}/${circuit_key}.zkey" 2>/dev/null || true
        rm -f "${circuit_dir}/${circuit_key}-0.zkey" 2>/dev/null || true
        rm -f "${circuit_dir}/${circuit_key}_verification_key.json" 2>/dev/null || true
    done
    
    # Clean bundle directories
    rm -rf nomos-circuits-* 2>/dev/null || true
    rm -rf prover-* 2>/dev/null || true
    rm -rf verifier-* 2>/dev/null || true
    rm -rf witness-generators/ 2>/dev/null || true
    rm -rf proving-keys/ 2>/dev/null || true
    
    log_success "Cleaned build artifacts"
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check OS
    if [[ "$(uname -s)" != "Linux" ]]; then
        log_error "This script is designed for Linux. Detected: $(uname -s)"
        exit 1
    fi
    
    # Check architecture
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
        log_warn "This script supports x86_64 and aarch64. Detected: $(uname -m)"
    else
        log_info "Detected architecture: $ARCH"
    fi
    
    log_success "System requirements check passed"
}

# Install system dependencies
install_dependencies() {
    if [[ "$SKIP_DEPS" == true ]]; then
        log_info "Skipping system dependency installation..."
        return
    fi
    
    log_info "Installing system dependencies..."
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -y
        sudo apt-get install -y \
            build-essential \
            cmake \
            libgmp-dev \
            libsodium-dev \
            nasm \
            curl \
            m4 \
            nlohmann-json3-dev \
            git
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y \
            gcc \
            gcc-c++ \
            make \
            cmake \
            gmp-devel \
            libsodium-devel \
            nasm \
            curl \
            m4 \
            json-devel \
            git
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm \
            base-devel \
            cmake \
            gmp \
            libsodium \
            nasm \
            curl \
            m4 \
            nlohmann-json \
            git
    else
        log_error "Unsupported package manager. Please install dependencies manually:"
        log_error "  build-essential, cmake, libgmp-dev, libsodium-dev, nasm, curl, m4, nlohmann-json3-dev, git"
        exit 1
    fi
    
    log_success "System dependencies installed"
}

# Install Rust and Circom
install_circom() {
    if [[ "$SKIP_CIRCOM" == true ]]; then
        log_info "Skipping Circom installation..."
        if ! command -v circom &> /dev/null; then
            log_error "circom not found in PATH. Please install it or remove --skip-circom"
            exit 1
        fi
        return
    fi
    
    log_info "Installing Circom..."
    
    # Check if Rust is installed
    if ! command -v cargo &> /dev/null; then
        log_info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
    
    # Clone and build Circom
    if [[ ! -d "$PROJECT_ROOT/circom" ]]; then
        git clone https://github.com/iden3/circom.git "$PROJECT_ROOT/circom"
    fi
    
    cd "$PROJECT_ROOT/circom"
    RUSTFLAGS="-A dead_code" cargo build --release
    RUSTFLAGS="-A dead_code" cargo install --path circom
    cd "$PROJECT_ROOT"
    
    # Verify installation
    circom --version
    
    log_success "Circom installed successfully"
}

# Install Node.js and snarkjs
install_snarkjs() {
    if [[ "$SKIP_SNARKJS" == true ]]; then
        log_info "Skipping snarkjs installation..."
        if ! command -v snarkjs &> /dev/null; then
            log_error "snarkjs not found in PATH. Please install it or remove --skip-snarkjs"
            exit 1
        fi
        return
    fi
    
    log_info "Installing snarkjs..."
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        log_info "Installing Node.js..."
        
        # Use NodeSource to install Node.js 20
        if command -v apt-get &> /dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif command -v dnf &> /dev/null; then
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            sudo dnf install -y nodejs
        else
            log_error "Please install Node.js 20 manually"
            exit 1
        fi
    fi
    
    # Install snarkjs globally
    sudo npm install -g snarkjs@latest
    
    # Verify installation
    snarkjs --version || true
    
    log_success "snarkjs installed successfully"
}

# Initialize git submodules
init_submodules() {
    log_info "Initializing git submodules..."
    git submodule update --init --recursive
    log_success "Git submodules initialized"
}

# Download Powers of Tau file
download_ptau() {
    if [[ "$SKIP_PTAU" == true ]]; then
        log_info "Skipping Powers of Tau download..."
        if [[ ! -f "$PROJECT_ROOT/$PTAU_FILE" ]]; then
            log_error "Powers of Tau file not found: $PROJECT_ROOT/$PTAU_FILE"
            exit 1
        fi
        return
    fi
    
    if [[ -f "$PROJECT_ROOT/$PTAU_FILE" ]]; then
        log_info "Powers of Tau file already exists, skipping download..."
        return
    fi
    
    log_info "Downloading Powers of Tau file (this may take a while, ~3GB)..."
    curl -L -o "$PROJECT_ROOT/$PTAU_FILE" "$PTAU_URL"
    log_success "Powers of Tau file downloaded"
}

# Generate proving key for a circuit
generate_proving_key() {
    local circuit_key="$1"
    
    if [[ ! -v CIRCUITS[$circuit_key] ]]; then
        log_error "Unknown circuit: $circuit_key"
        exit 1
    fi
    
    IFS=':' read -r circuit_path circuit_name display_name <<< "${CIRCUITS[$circuit_key]}"
    local circuit_dir="$PROJECT_ROOT/$(dirname "$circuit_path")"
    local circuit_file=$(basename "$circuit_path")
    local circuit_filestem=$(basename "$circuit_path" .circom)
    
    log_info "Generating proving key for $display_name..."
    
    cd "$circuit_dir"
    
    # Generate R1CS
    log_info "  Generating R1CS constraints..."
    circom --r1cs --O2 "$circuit_file"
    
    # Determine the R1CS file name (some circuits have different names)
    local r1cs_file="${circuit_filestem}.r1cs"
    
    # Setup
    log_info "  Running Groth16 setup..."
    snarkjs groth16 setup "$r1cs_file" "$PROJECT_ROOT/$PTAU_FILE" "${circuit_key}-0.zkey"
    
    # Contribute to ceremony
    log_info "  Contributing to ceremony..."
    head -c 32 /dev/urandom | xxd -p -c 256 | snarkjs zkey contribute "${circuit_key}-0.zkey" "${circuit_key}.zkey" --name="LOCAL_BUILD" -v
    
    # Export verification key
    log_info "  Exporting verification key..."
    snarkjs zkey export verificationkey "${circuit_key}.zkey" "${circuit_key}_verification_key.json"
    
    # Cleanup intermediate file
    rm -f "${circuit_key}-0.zkey"
    
    cd "$PROJECT_ROOT"
    
    log_success "Proving key generated for $display_name"
}

# Generate all proving keys
generate_all_proving_keys() {
    if [[ "$SKIP_PROVING_KEYS" == true ]]; then
        log_info "Skipping proving key generation..."
        return
    fi
    
    log_info "Generating proving keys for all circuits..."
    
    local circuits_to_build
    if [[ -n "$SINGLE_CIRCUIT" ]]; then
        circuits_to_build=("$SINGLE_CIRCUIT")
    else
        circuits_to_build=("${!CIRCUITS[@]}")
    fi
    
    for circuit_key in "${circuits_to_build[@]}"; do
        generate_proving_key "$circuit_key"
    done
    
    log_success "All proving keys generated"
}

# Compile witness generator for a circuit
compile_witness_generator() {
    local circuit_key="$1"
    
    if [[ ! -v CIRCUITS[$circuit_key] ]]; then
        log_error "Unknown circuit: $circuit_key"
        exit 1
    fi
    
    IFS=':' read -r circuit_path circuit_name display_name <<< "${CIRCUITS[$circuit_key]}"
    local circuit_dir="$PROJECT_ROOT/$(dirname "$circuit_path")"
    local circuit_file=$(basename "$circuit_path")
    local circuit_filestem=$(basename "$circuit_path" .circom)
    local circuit_cpp_dir="${circuit_dir}/${circuit_filestem}_cpp"
    
    log_info "Compiling witness generator for $display_name..."
    
    cd "$circuit_dir"
    
    # Generate C++ code for witness computation
    log_info "  Generating C++ code..."
    circom --c --r1cs --no_asm --O2 "$circuit_file"
    
    # Replace Makefile with our custom one
    log_info "  Copying custom Makefile..."
    cp "$PROJECT_ROOT/.github/resources/witness-generator/Makefile" "${circuit_filestem}_cpp/Makefile"
    
    # Compile the witness generator
    log_info "  Compiling..."
    cd "${circuit_filestem}_cpp"
    make PROJECT="$circuit_filestem" linux
    
    cd "$PROJECT_ROOT"
    
    log_success "Witness generator compiled for $display_name"
}

# Compile all witness generators
compile_all_witness_generators() {
    if [[ "$SKIP_WITNESS" == true ]]; then
        log_info "Skipping witness generator compilation..."
        return
    fi
    
    log_info "Compiling witness generators for all circuits..."
    
    local circuits_to_build
    if [[ -n "$SINGLE_CIRCUIT" ]]; then
        circuits_to_build=("$SINGLE_CIRCUIT")
    else
        circuits_to_build=("${!CIRCUITS[@]}")
    fi
    
    for circuit_key in "${circuits_to_build[@]}"; do
        compile_witness_generator "$circuit_key"
    done
    
    log_success "All witness generators compiled"
}

# Download GMP archive if needed
download_gmp() {
    local gmp_dir="$PROJECT_ROOT/rapidsnark/depends"
    local gmp_file="gmp-6.2.1.tar.xz"
    
    if [[ -f "$gmp_dir/$gmp_file" ]]; then
        log_info "GMP archive already exists, skipping download..."
        return
    fi
    
    log_info "Downloading GMP archive..."
    mkdir -p "$gmp_dir"
    curl -L -o "$gmp_dir/$gmp_file" "https://ftpmirror.gnu.org/gmp/gmp-6.2.1.tar.xz"
    log_success "GMP archive downloaded"
}

# Compile prover and verifier
compile_prover_verifier() {
    if [[ "$SKIP_PROVER" == true ]]; then
        log_info "Skipping prover/verifier compilation..."
        return
    fi
    
    log_info "Compiling prover and verifier..."
    
    # Replace Makefile with our custom one
    log_info "  Replacing Makefile..."
    cp "$PROJECT_ROOT/.github/resources/prover/Makefile" "$PROJECT_ROOT/rapidsnark/Makefile"
    
    # Download GMP if needed
    download_gmp
    
    cd "$PROJECT_ROOT/rapidsnark"
    
    # Build GMP (ignore exit code if already built)
    log_info "  Building GMP..."
    ./build_gmp.sh host || true
    
    # Verify GMP is available
    if [[ ! -d "depends/gmp/package" ]]; then
        log_error "GMP package not found after build_gmp.sh"
        exit 1
    fi
    
    # For ARM64, CMake expects package_aarch64 but build_gmp.sh host creates package
    # Create symlink to fix the path mismatch
    if [[ "$ARCH" == "aarch64" ]]; then
        if [[ -d "depends/gmp/package" && ! -e "depends/gmp/package_aarch64" ]]; then
            log_info "  Creating symlink for ARM64 GMP package..."
            ln -s package depends/gmp/package_aarch64
        fi
    fi
    
    # Build prover and verifier based on architecture
    log_info "  Building prover and verifier (static) for $ARCH..."
    if [[ "$ARCH" == "aarch64" ]]; then
        make host_linux_arm64_static
    else
        make host_linux_x86_64_static
    fi
    
    cd "$PROJECT_ROOT"
    
    log_success "Prover and verifier compiled"
}

# Create the unified release bundle
create_bundle() {
    local bundle_name="nomos-circuits-${VERSION}-${OS}-${ARCH}"
    
    log_info "Creating unified release bundle: $bundle_name"
    
    # Create bundle directory structure
    mkdir -p "${bundle_name}"/{pol,poq,zksign,poc}
    
    # Create VERSION file
    echo "$VERSION" > "${bundle_name}/VERSION"
    
    # Copy prover and verifier
    if [[ ! "$SKIP_PROVER" == true ]]; then
        log_info "  Copying prover and verifier..."
        cp "$PROJECT_ROOT/rapidsnark/package/bin/prover" "${bundle_name}/prover"
        cp "$PROJECT_ROOT/rapidsnark/package/bin/verifier" "${bundle_name}/verifier"
        chmod +x "${bundle_name}/prover"
        chmod +x "${bundle_name}/verifier"
    fi
    
    # Copy witness generators and proving keys for each circuit
    local circuits_to_bundle
    if [[ -n "$SINGLE_CIRCUIT" ]]; then
        circuits_to_bundle=("$SINGLE_CIRCUIT")
    else
        circuits_to_bundle=("${!CIRCUITS[@]}")
    fi
    
    for circuit_key in "${circuits_to_bundle[@]}"; do
        IFS=':' read -r circuit_path circuit_name display_name <<< "${CIRCUITS[$circuit_key]}"
        local circuit_dir="$PROJECT_ROOT/$(dirname "$circuit_path")"
        local circuit_filestem=$(basename "$circuit_path" .circom)
        local circuit_cpp_dir="${circuit_dir}/${circuit_filestem}_cpp"
        
        log_info "  Bundling $display_name..."
        
        # Copy witness generator
        if [[ ! "$SKIP_WITNESS" == true ]]; then
            if [[ -f "${circuit_cpp_dir}/${circuit_filestem}" ]]; then
                cp "${circuit_cpp_dir}/${circuit_filestem}" "${bundle_name}/${circuit_key}/witness_generator"
                chmod +x "${bundle_name}/${circuit_key}/witness_generator"
            fi
            if [[ -f "${circuit_cpp_dir}/${circuit_filestem}.dat" ]]; then
                cp "${circuit_cpp_dir}/${circuit_filestem}.dat" "${bundle_name}/${circuit_key}/witness_generator.dat"
            fi
        fi
        
        # Copy proving key and verification key
        if [[ ! "$SKIP_PROVING_KEYS" == true ]]; then
            if [[ -f "${circuit_dir}/${circuit_key}.zkey" ]]; then
                cp "${circuit_dir}/${circuit_key}.zkey" "${bundle_name}/${circuit_key}/proving_key.zkey"
            fi
            if [[ -f "${circuit_dir}/${circuit_key}_verification_key.json" ]]; then
                cp "${circuit_dir}/${circuit_key}_verification_key.json" "${bundle_name}/${circuit_key}/verification_key.json"
            fi
        fi
    done
    
    # Create tarball
    log_info "  Creating tarball..."
    tar -czf "${bundle_name}.tar.gz" "${bundle_name}"
    
    log_success "Bundle created: ${bundle_name}.tar.gz"
    
    # Print bundle contents
    log_info "Bundle contents:"
    tar -tzf "${bundle_name}.tar.gz" | head -50
}

# Print build summary
print_summary() {
    echo ""
    log_info "=========================================="
    log_info "Build Summary"
    log_info "=========================================="
    log_info "Version: $VERSION"
    log_info "OS: $OS"
    log_info "Architecture: $ARCH"
    echo ""
    
    if [[ -n "$SINGLE_CIRCUIT" ]]; then
        log_info "Built circuit: $SINGLE_CIRCUIT"
    else
        log_info "Built circuits: pol, poq, zksign, poc"
    fi
    echo ""
    
    log_info "Skip flags:"
    log_info "  - Dependencies: $SKIP_DEPS"
    log_info "  - Circom: $SKIP_CIRCOM"
    log_info "  - snarkjs: $SKIP_SNARKJS"
    log_info "  - Powers of Tau: $SKIP_PTAU"
    log_info "  - Proving Keys: $SKIP_PROVING_KEYS"
    log_info "  - Prover/Verifier: $SKIP_PROVER"
    log_info "  - Witness Generators: $SKIP_WITNESS"
    echo ""
    
    local bundle_name="nomos-circuits-${VERSION}-${OS}-${ARCH}"
    if [[ -f "${bundle_name}.tar.gz" ]]; then
        local size=$(du -h "${bundle_name}.tar.gz" | cut -f1)
        log_success "Output bundle: ${bundle_name}.tar.gz ($size)"
    fi
    log_info "=========================================="
}

# Main function
main() {
    parse_args "$@"
    
    # Change to project root directory so all relative paths work correctly
    cd "$PROJECT_ROOT"
    
    echo ""
    log_info "=========================================="
    log_info "Logos Blockchain Circuits - Local Build"
    log_info "=========================================="
    log_info "Version: $VERSION"
    log_info "Starting build process..."
    echo ""
    
    # Clean if requested
    if [[ "$CLEAN" == true ]]; then
        clean_artifacts
    fi
    
    # Check requirements
    check_requirements
    
    # Install dependencies
    install_dependencies
    
    # Initialize submodules
    init_submodules
    
    # Install Circom
    install_circom
    
    # Install snarkjs
    install_snarkjs
    
    # Download Powers of Tau
    download_ptau
    
    # Generate proving keys
    generate_all_proving_keys
    
    # Compile prover and verifier
    compile_prover_verifier
    
    # Compile witness generators
    compile_all_witness_generators
    
    # Create bundle
    create_bundle
    
    # Print summary
    print_summary
    
    log_success "Build completed successfully!"
}

# Run main function
main "$@"