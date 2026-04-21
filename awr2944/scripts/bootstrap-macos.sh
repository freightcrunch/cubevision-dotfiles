#!/usr/bin/env bash
# ============================================================================
# bootstrap-macos.sh
# Bootstrap the AWR2944 development environment on a macOS host (Apple Silicon
# or Intel). This script installs host-side tooling only: Rust, ARM GCC, Docker,
# and serial-port utilities. The TI MMWAVE-MCUPLUS-SDK itself is NOT installed
# natively on macOS (TI does not support macOS) — firmware builds run inside
# the Docker image defined in ../docker/Dockerfile.
#
# Re-running this script is safe; each step is idempotent.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ----- Logging helpers -------------------------------------------------------
log()  { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# ----- Preconditions ---------------------------------------------------------
[[ "$(uname -s)" == "Darwin" ]] || die "This script is for macOS. Use bootstrap-linux-arm64.sh on Linux."

ARCH="$(uname -m)"
log "Detected macOS on ${ARCH}"

# ----- 1. Homebrew -----------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  log "Homebrew already installed"
fi

# Ensure the Apple Silicon brew prefix is on PATH for the rest of this shell
if [[ "${ARCH}" == "arm64" && -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ----- 2. Core CLI dependencies ---------------------------------------------
log "Installing core packages via brew…"
BREW_PACKAGES=(
  git
  cmake
  ninja
  python@3.11
  libusb          # required by many JTAG/serial tools
  minicom         # serial console for the EVM control port
  tio             # modern serial terminal, nicer than minicom
  pkg-config
  wget
  curl
  coreutils       # gstat, ggrep, etc. for portable scripts
  dos2unix
  jq              # for release-notes parsing in verify-env.sh
)
brew install "${BREW_PACKAGES[@]}"

# ----- 3. ARM bare-metal toolchain (GNU) -------------------------------------
# The arm-none-eabi toolchain is used for R5F firmware when you don't want to
# install TI's proprietary ti-cgt-armllvm host-side. The Docker image ships
# the TI compiler as well; this native install is for quick host compiles and
# IDE support.
log "Installing GNU Arm Embedded Toolchain (arm-none-eabi)…"
brew tap ArmMbed/homebrew-formulae 2>/dev/null || true
brew install --cask gcc-arm-embedded 2>/dev/null || \
  brew install gcc-arm-embedded 2>/dev/null || \
  warn "Could not install gcc-arm-embedded via brew; see docs/02-toolchains.md for manual instructions."

# ----- 4. Docker Desktop -----------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  log "Docker not found — installing Docker Desktop cask…"
  brew install --cask docker
  warn "Launch Docker Desktop once manually to accept the license before running builds."
else
  log "Docker already installed ($(docker --version))"
fi

# ----- 5. Rust via rustup ----------------------------------------------------
if ! command -v rustup >/dev/null 2>&1; then
  log "Installing rustup…"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
  # shellcheck disable=SC1091
  source "${HOME}/.cargo/env"
else
  log "rustup already installed"
fi

log "Installing Rust stable + host-aligned components…"
rustup toolchain install stable
rustup default stable
rustup component add rust-src rustfmt clippy llvm-tools-preview

# AWR2944 MSS core = Arm Cortex-R5F (armv7r-a, hard-float). See docs/02-toolchains.md.
log "Adding armv7r-none-eabihf target for Cortex-R5F firmware builds…"
rustup target add armv7r-none-eabihf

# Helpful cargo subcommands for embedded work.
log "Installing cargo helpers (cargo-binutils, probe-rs, cargo-generate)…"
cargo install --locked cargo-binutils probe-rs-tools cargo-generate || \
  warn "One or more cargo installs failed; see docs/05-troubleshooting.md."

# ----- 6. Python host tooling ------------------------------------------------
# Used by pymmw / pyRadar / TI's post-processing reference scripts.
log "Creating Python venv for host-side radar post-processing…"
PYBIN="$(brew --prefix python@3.11)/bin/python3.11"
"${PYBIN}" -m venv "${REPO_ROOT}/.venv"
# shellcheck disable=SC1091
source "${REPO_ROOT}/.venv/bin/activate"
pip install --upgrade pip wheel
pip install numpy scipy matplotlib pyserial

# ----- 7. XDS110 / serial permissions on macOS -------------------------------
# On macOS the XDS110 exposes two /dev/tty.usbmodem* interfaces. No udev is
# needed; however, on Apple Silicon the TI UniFlash / CCS stack currently runs
# under Rosetta 2. Install Rosetta if missing.
if [[ "${ARCH}" == "arm64" ]]; then
  if ! /usr/bin/pgrep -q oahd; then
    log "Installing Rosetta 2 (required for TI UniFlash on Apple Silicon)…"
    softwareupdate --install-rosetta --agree-to-license || \
      warn "Rosetta install failed; install manually before running UniFlash."
  else
    log "Rosetta 2 already present"
  fi
fi

# ----- 8. Summary ------------------------------------------------------------
cat <<EOF

$(printf '\033[1;32m✓ macOS bootstrap complete.\033[0m')

Next steps:
  1. Launch Docker Desktop once and accept the license.
  2. Build the reproducible SDK image:
       cd ${REPO_ROOT}/docker && docker compose build
  3. Plug in the AWR2944EVM via USB-C and verify the two serial devices appear:
       ls /dev/tty.usbmodem*
  4. Read ${REPO_ROOT}/README.md for the full onboarding walkthrough.
  5. Run ${REPO_ROOT}/scripts/verify-env.sh to sanity-check the install.

EOF
