#!/bin/bash

set -euo pipefail

# Default values
BUILD_DIR="$(pwd)/build"
INSTALL_PREFIX=""

# Help function
help_f() {
    cat <<EOF
Local installation script for OpenVAF-Reloaded and VACASK
Based on the Containerfile from ubuntu24_image
Tested on Ubuntu 24.04

Usage: sudo ./vacask_script.sh [OPTIONS]

Options:
  --build-dir DIR, -b DIR       Specify build directory (default: <pwd>/build)
  --install-prefix DIR, -p DIR  Specify installation prefix (default: <BUILD_DIR>/..)
  --help, -h                    Show this help message

Examples:
  sudo ./vacask_script.sh
  sudo ./vacask_script.sh --build-dir /tmp/vacask-build
  sudo ./vacask_script.sh -b /my/build/dir -p /my/install/dir

Written by Miikka Mäki, 23.10.2026
Vibe coded with Mistral Vibe
EOF
    exit 0
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-dir|-b)
            BUILD_DIR="$2"
            shift 2
            ;;
        --install-prefix|-p)
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        --help|-h)
            help_f
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Run with --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Set INSTALL_PREFIX if not specified
if [ -z "$INSTALL_PREFIX" ]; then
    INSTALL_PREFIX="$(dirname "$BUILD_DIR")"
fi

# Resolve to absolute paths to avoid issues with relative paths
if [[ "$BUILD_DIR" != /* ]]; then
    BUILD_DIR="$(cd "$BUILD_DIR" 2>/dev/null && pwd || echo "$BUILD_DIR")"
fi
if [[ "$INSTALL_PREFIX" != /* ]]; then
    INSTALL_PREFIX="$(cd "$INSTALL_PREFIX" 2>/dev/null && pwd || echo "$INSTALL_PREFIX")"
fi

# Ensure we're running as root (for apt-get)
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)" >&2
    exit 1
fi

# Verify we're on Ubuntu 24.04 or compatible
if ! grep -q '24.04' /etc/os-release && ! grep -q '24.04' /usr/lib/os-release; then
    echo "WARNING: This script is designed for Ubuntu 24.04" >&2
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Configuration - Derived paths
OPENVAF_SRC="$BUILD_DIR/openvaf-src"
VACASK_SRC="$BUILD_DIR/vacask-src"
BOOST_SRC="$BUILD_DIR/boost_1_88_0"
BOOST_TAR="$BUILD_DIR/boost.tar.gz"
SUPERLU_SRC="$BUILD_DIR/superlu_mt-4.0.0"
SUPERLU_TAR="$BUILD_DIR/superlu_mt.tar.gz"

echo "==========================================="
echo "OpenVAF-Reloaded and VACASK Local Installer"
echo "Build directory: $BUILD_DIR"
echo "Install prefix:  $INSTALL_PREFIX"
echo "==========================================="

# Helper function to check if a command exists and works
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Create installation and build directories
mkdir -p "$INSTALL_PREFIX/bin"
mkdir -p "$BUILD_DIR"

# Step 1/7: Install required system packages
echo ""
echo "Step 1/7: Installing system dependencies..."
apt-get update
apt-get install -y \
    ca-certificates \
    curl \
    wget \
    git \
    gawk \
    perl \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    libffi-dev \
    libexpat1-dev \
    libboost-all-dev \
    libreadline-dev \
    libopenblas-dev \
    libfftw3-dev \
    libsuitesparse-dev \
    libtomlplusplus-dev \
    zlib1g-dev

# Add cargo to PATH immediately
export PATH="/root/.cargo/bin:$PATH"

# Step 2/7: Install LLVM 21
if [ ! -f /usr/lib/llvm-21/bin/clang++ ] || [ ! -f /usr/lib/llvm-21/bin/clang ]; then
    echo ""
    echo "Step 2/7: Installing LLVM 21..."
    cd "$BUILD_DIR"
    wget -q https://apt.llvm.org/llvm.sh -O llvm.sh
    chmod +x llvm.sh
    ./llvm.sh 21
    rm -f llvm.sh
    export PATH="/usr/lib/llvm-21/bin:$PATH"
    echo "LLVM 21 installed successfully."
else
    echo ""
    echo "Step 2/7: LLVM 21 already installed. Skipping."
    export PATH="/usr/lib/llvm-21/bin:$PATH"
fi

# Step 3/7: Install Rust toolchain
if ! command_exists cargo || ! command_exists rustc; then
    echo ""
    echo "Step 3/7: Installing Rust toolchain..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    export PATH="$HOME/.cargo/bin:$PATH"
    echo "Rust toolchain installed successfully."
else
    echo ""
    echo "Step 3/7: Rust toolchain already installed. Skipping."
    source "$HOME/.cargo/env"
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# Step 4/7: Clone and build OpenVAF-Reloaded
if [ -x "$INSTALL_PREFIX/bin/openvaf" ] && "$INSTALL_PREFIX/bin/openvaf" --version >/dev/null 2>&1; then
    echo ""
    echo "Step 4/7: OpenVAF-Reloaded already built and installed. Skipping."
else
    echo ""
    echo "Step 4/7: Building OpenVAF-Reloaded..."
    rm -rf "$OPENVAF_SRC"
    git clone --recursive https://github.com/OpenVAF/OpenVAF-Reloaded.git "$OPENVAF_SRC"
    cd "$OPENVAF_SRC"
    ./configure
    ./build.sh --release
    install -Dm755 target/release/openvaf-r "$INSTALL_PREFIX/bin/openvaf"
    echo "OpenVAF installed: $($INSTALL_PREFIX/bin/openvaf --version)"
fi

# Step 5/7: Install Boost 1.88.0
if [ -d "$BOOST_SRC/stage/lib" ] && [ -f "$BOOST_SRC/stage/lib/libboost_filesystem.a" ] && [ -f "$BOOST_SRC/stage/lib/libboost_system.a" ] && [ -f "$BOOST_SRC/stage/lib/libboost_thread.a" ]; then
    echo ""
    echo "Step 5/7: Boost 1.88.0 already built. Skipping."
else
    echo ""
    echo "Step 5/7: Building Boost 1.88.0..."
    rm -rf "$BOOST_SRC" "$BOOST_TAR"
    cd "$BUILD_DIR"
    wget -q https://archives.boost.io/release/1.88.0/source/boost_1_88_0.tar.gz -O "$BOOST_TAR"
    tar -xzf "$BOOST_TAR" -C "$BUILD_DIR"
    cd "$BOOST_SRC"
    ./bootstrap.sh
    ./b2 --with-filesystem --with-process --with-asio link=static toolset=gcc
fi

# Step 6/7: Install SuperLU_MT 4.0.0
if [ -d "$SUPERLU_SRC" ] && [ -f "$SUPERLU_SRC/lib/libsuperlu_mt.a" ]; then
    echo ""
    echo "Step 6/7: SuperLU_MT 4.0.0 already built. Skipping."
else
    echo ""
    echo "Step 6/7: Building SuperLU_MT 4.0.0..."
    rm -rf "$SUPERLU_SRC" "$SUPERLU_TAR"
    cd "$BUILD_DIR"
    wget -q https://fides.fe.uni-lj.si/vacask/superlu_mt-4.0.0.tar.gz -O "$SUPERLU_TAR"
    tar -xzf "$SUPERLU_TAR" -C "$BUILD_DIR"
    cd "$SUPERLU_SRC"
    make
fi

# Step 7/7: Clone and build VACASK
if [ -x "$INSTALL_PREFIX/bin/vacask" ]; then
    echo ""
    echo "Step 7/7: VACASK already built and installed. Skipping."
else
    echo ""
    echo "Step 7/7: Building and installing VACASK..."
    rm -rf "$VACASK_SRC"
    cd "$BUILD_DIR"
    git clone https://codeberg.org/arpadbuermen/VACASK.git "$VACASK_SRC"
    cd "$VACASK_SRC"
    mkdir -p build
    cmake -G "Unix Makefiles" -B build -DCMAKE_BUILD_TYPE=Release \
        -DOPENVAF_DIR="$OPENVAF_SRC/target/release" \
        -DBoost_ROOT="$BOOST_SRC/stage" \
        -DSuperluMT_DIR="$SUPERLU_SRC" \
        -DCADNIP_PARSERS=ON \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"
    cmake --build build
    cmake --install build --prefix "$INSTALL_PREFIX"
fi

# Verify installation
echo ""
echo "Verifying installations..."

VERIFY_OK=true

# Check OpenVAF
if [ -x "$INSTALL_PREFIX/bin/openvaf" ]; then
    echo "OpenVAF: OK - $($INSTALL_PREFIX/bin/openvaf --version)"
else
    echo "OpenVAF: FAILED - not found at $INSTALL_PREFIX/bin/openvaf"
    VERIFY_OK=false
fi

# Check VACASK
if [ -x "$INSTALL_PREFIX/bin/vacask" ]; then
    VACASK_VERSION=$("$INSTALL_PREFIX/bin/vacask" --version 2>&1 | head -1 || echo "version unknown")
    echo "VACASK: OK - $VACASK_VERSION"
else
    echo "VACASK: FAILED - not found at $INSTALL_PREFIX/bin/vacask"
    VERIFY_OK=false
fi

# Check Boost libraries
if [ -d "$BOOST_SRC/stage/lib" ]; then
    echo "Boost: OK - stage libraries found at $BOOST_SRC/stage/lib"
else
    echo "Boost: FAILED - stage libraries not found at $BOOST_SRC/stage/lib"
    VERIFY_OK=false
fi

# Check SuperLU_MT
if [ -f "$SUPERLU_SRC/lib/libsuperlu_mt.a" ]; then
    echo "SuperLU_MT: OK - library found at $SUPERLU_SRC/lib/libsuperlu_mt.a"
else
    echo "SuperLU_MT: WARNING - library not found at $SUPERLU_SRC/lib/libsuperlu_mt.a (may affect VACASK)"
fi

if [ "$VERIFY_OK" = false ]; then
    echo ""
    echo "WARNING: Some components failed verification!"
    exit 1
fi

# Cleanup build artifacts
echo ""
echo "Cleaning up build artifacts..."
# Only clean up if we built in this run - but for now, just clean temp files
# Keep source directories for potential debugging/rebuilding
rm -f "$BOOST_TAR" "$SUPERLU_TAR" 2>/dev/null || true

echo ""
echo "==========================================="
echo "Installation complete!"
echo "OpenVAF and VACASK are now available in $INSTALL_PREFIX/bin"
echo "Build files kept in: $BUILD_DIR"
echo "Add to PATH: export PATH="\$INSTALL_PREFIX/bin:\$PATH""
echo "==========================================="