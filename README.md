# OpenVAF-Reloaded and VACASK Installer

Local installation script for **OpenVAF-Reloaded** and **VACASK** tools.

Based on the Containerfile from `ubuntu24_image`.
Tested on **Ubuntu 24.04**.

## Overview

This script automates the installation of OpenVAF-Reloaded and VACASK, including all their dependencies:

- LLVM 21
- Rust toolchain
- OpenVAF-Reloaded
- Boost 1.88.0
- SuperLU_MT 4.0.0
- VACASK

The script supports **resumable installations** - it will skip any steps that have already been completed successfully.

## Usage

```bash
# Basic installation (installs to ./ and builds in ./build)
sudo ./install.sh

# Custom build directory
sudo ./install.sh --build-dir /path/to/build
sudo ./install.sh -b /path/to/build

# Custom installation prefix
sudo ./install.sh --install-prefix /path/to/install
sudo ./install.sh -p /path/to/install

# Both custom build and install locations
sudo ./install.sh -b /my/build/dir -p /my/install/dir

# Show help
sudo ./install.sh --help
sudo ./install.sh -h
```

### Notes

- The script must be run as **root** (requires sudo) for system package installation
- By default, builds go to `./build` and binaries are installed to the current directory
- If INSTALL_PREFIX is not specified, it defaults to the parent of BUILD_DIR
- After installation, add to PATH: `export PATH="$INSTALL_PREFIX/bin:$PATH"`

## Requirements

- Ubuntu 24.04 (recommended)
- Root access (for apt-get)
- Internet connection (for downloading dependencies)

## Credits

### Tools

- **OpenVAF-Reloaded**: [https://github.com/OpenVAF/OpenVAF-Reloaded](https://github.com/OpenVAF/OpenVAF-Reloaded)
- **VACASK**: [https://codeberg.org/arpadbuermen/VACASK](https://codeberg.org/arpadbuermen/VACASK)
- **LLVM**: [https://www.llvm.org/](https://www.llvm.org/)
- **Rust**: [https://www.rust-lang.org/](https://www.rust-lang.org/)
- **Boost**: [https://www.boost.org/](https://www.boost.org/)
- **SuperLU_MT**: [https://fides.fe.uni-lj.si/vacask/](https://fides.fe.uni-lj.si/vacask/)

### Authors

This installer script was created by **Miikka Mäki** (23.10.2026) with assistance from **Mistral Vibe**.

---