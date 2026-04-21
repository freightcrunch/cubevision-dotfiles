#!/usr/bin/env bash
# ============================================================================
# bootstrap-linux-arm64.sh
# Bootstrap the AWR2944 development environment on an arm64 Linux dev target
# (Raspberry Pi 5, NVIDIA Jetson, Ampere-based workstation, etc.).
#
# TI's MMWAVE-MCUPLUS-SDK installer and the TI-CGT-ARMLLVM compiler are
# x86_64-only. On arm64 Linux, we run those pieces inside the Docker image
# defined in ../docker/Dockerfile, which uses buildx/qemu for x86_64 emulation.
# The host still needs: Rust, GNU Arm Embedded Toolchain, Python venv, udev
# rules for the XDS110, and Docker.
#
# Tested on: Ubuntu 22.04 arm64, Ubuntu 24.04 arm64, Debian 12 arm64.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log()  { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Linux" ]] || die "Run this script on Linux. For macOS use bootstrap-macos.sh."

ARCH="$(uname -m)"
if [[ "${ARCH}" != "aarch64" && "${ARCH}" != "arm64" ]]; then
  warn "Detected ${ARCH}, not arm64 — this script still works but was tuned for arm64 dev targets."
fi

SUDO="sudo"
if [[ $EUID -eq 0 ]]; then SUDO=""; fi

# ----- 1. APT dependencies ---------------------------------------------------
log "Updating apt indexes…"
${SUDO} apt-get update -y

log "Installing core packages…"
${SUDO} apt-get install -y --no-install-recommends \
  build-essential \
  git \
  curl wget ca-certificates \
  cmake ninja-build pkg-config \
  python3 python3-venv python3-pip \
  libusb-1.0-0-dev libudev-dev libssl-dev \
  minicom tio picocom \
  usbutils \
  dos2unix jq \
  qemu-user-static binfmt-support \
  gnupg lsb-release

# ----- 2. GNU Arm Embedded Toolchain ----------------------------------------
# Ubuntu 22.04+ ships gcc-arm-none-eabi in apt; fall back to the Arm tarball
# if apt version is too old for the R5F multilib.
if ! command -v arm-none-eabi-gcc >/dev/null 2>&1; then
  log "Installing gcc-arm-none-eabi from apt…"
  ${SUDO} apt-get install -y --no-install-recommends gcc-arm-none-eabi
fi

GCC_VER="$(arm-none-eabi-gcc -dumpversion 2>/dev/null || echo 0)"
GCC_MAJOR="${GCC_VER%%.*}"
if [[ "${GCC_MAJOR:-0}" -lt 11 ]]; then
  warn "apt gcc-arm-none-eabi is too old (${GCC_VER}); installing Arm's tarball."
  TARBALL_URL="https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-aarch64-arm-none-eabi.tar.xz"
  tmp="$(mktemp -d)"
  curl -fsSL "${TARBALL_URL}" -o "${tmp}/arm-gnu.tar.xz"
  ${SUDO} mkdir -p /opt/arm-gnu-toolchain
  ${SUDO} tar -xJf "${tmp}/arm-gnu.tar.xz" -C /opt/arm-gnu-toolchain --strip-components=1
  echo 'export PATH=/opt/arm-gnu-toolchain/bin:$PATH' | ${SUDO} tee /etc/profile.d/arm-gnu.sh >/dev/null
  export PATH=/opt/arm-gnu-toolchain/bin:$PATH
fi
log "arm-none-eabi-gcc: $(arm-none-eabi-gcc -dumpversion)"

# ----- 3. Docker Engine (arm64) ---------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker Engine…"
  ${SUDO} install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    ${SUDO} gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  ${SUDO} chmod a+r /etc/apt/keyrings/docker.gpg
  # shellcheck disable=SC1091
  . /etc/os-release
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
     https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" | \
    ${SUDO} tee /etc/apt/sources.list.d/docker.list >/dev/null
  ${SUDO} apt-get update -y
  ${SUDO} apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  ${SUDO} usermod -aG docker "$(whoami)" || true
  warn "You may need to log out / in for docker group membership to take effect."
fi

# Enable qemu so x86_64 TI installers can run on arm64.
log "Registering binfmt handlers for x86_64 emulation…"
${SUDO} docker run --privileged --rm tonistiigi/binfmt --install amd64 || \
  warn "binfmt registration failed — re-run after docker is fully up."

# ----- 4. udev rules for XDS110 ---------------------------------------------
log "Installing udev rules for TI XDS110 + CP210x USB-serial…"
${SUDO} install -m 0644 "${REPO_ROOT}/udev/71-ti-xds110.rules" /etc/udev/rules.d/71-ti-xds110.rules
${SUDO} udevadm control --reload-rules
${SUDO} udevadm trigger

# Ensure the invoking user is in the dialout group so they can open /dev/ttyACM*.
${SUDO} usermod -aG dialout "$(whoami)" || true

# ----- 5. Rust + embedded targets -------------------------------------------
if ! command -v rustup >/dev/null 2>&1; then
  log "Installing rustup…"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
  # shellcheck disable=SC1091
  source "${HOME}/.cargo/env"
fi

rustup toolchain install stable
rustup default stable
rustup component add rust-src rustfmt clippy llvm-tools-preview
rustup target add armv7r-none-eabihf

log "Installing cargo helpers…"
cargo install --locked cargo-binutils probe-rs-tools cargo-generate || \
  warn "cargo install had a failure; see docs/05-troubleshooting.md."

# ----- 6. Python venv for host analytics ------------------------------------
log "Creating Python venv at ${REPO_ROOT}/.venv…"
python3 -m venv "${REPO_ROOT}/.venv"
# shellcheck disable=SC1091
source "${REPO_ROOT}/.venv/bin/activate"
pip install --upgrade pip wheel
pip install numpy scipy matplotlib pyserial

cat <<EOF

$(printf '\033[1;32m✓ arm64 Linux bootstrap complete.\033[0m')

Next steps:
  1. Log out and back in so 'dialout' and 'docker' group membership activates.
  2. Build the reproducible SDK image (uses qemu-user-static for x86_64):
       cd ${REPO_ROOT}/docker && docker compose build
  3. Plug in the AWR2944EVM; confirm two /dev/ttyACM* nodes appear.
  4. Run ${REPO_ROOT}/scripts/verify-env.sh to sanity-check the install.

EOF
