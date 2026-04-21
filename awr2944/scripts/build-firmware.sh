#!/usr/bin/env bash
# ============================================================================
# build-firmware.sh
# Convenience wrapper that dispatches a firmware build into the Docker image
# (where TI-CGT-ARMLLVM and the MMWAVE-MCUPLUS-SDK live) regardless of whether
# you're on macOS or arm64 Linux.
#
# Usage:
#   ./scripts/build-firmware.sh ti mmw_demo            # C demo via TI SDK
#   ./scripts/build-firmware.sh rust                   # Rust R5F firmware
#   ./scripts/build-firmware.sh clean
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

die() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

MODE="${1:-}"
shift || true

case "${MODE}" in
  ti)
    DEMO="${1:-mmw}"
    echo "→ Building TI ${DEMO} inside the SDK container…"
    docker compose -f docker/docker-compose.yml run --rm sdk bash -lc "
      set -euo pipefail
      SDK_DIR=\$(ls -d /ti/mmwave_mcuplus_sdk_* | head -n1)
      [ -d \"\$SDK_DIR\" ] || { echo 'SDK not installed — run /opt/scripts/install-ti-sdk.sh first'; exit 1; }

      # Set all build environment variables (we don't have CCS, so setenv.sh won't work)
      export MMWAVE_SDK_DEVICE=awr2944
      export DOWNLOAD_FROM_CCS=yes
      export MMWAVE_SDK_TOOLS_INSTALL_PATH=/ti
      export MMWAVE_SDK_INSTALL_PATH=\$SDK_DIR
      export R5F_CLANG_INSTALL_PATH=/ti/ti-cgt-armllvm_4.0.2.LTS
      export C66X_CODEGEN_INSTALL_PATH=/ti/ti-cgt-c6000_8.3.13
      export SYSCONFIG_INSTALL_PATH=/ti/sysconfig_1.23.0
      export MCU_PLUS_INSTALL_PATH=/ti/mcu_plus_sdk_awr294x_10_01_00_04
      export MCU_PLUS_AWR294X_INSTALL_PATH=/ti/mcu_plus_sdk_awr294x_10_01_00_04
      export MCU_PLUS_AWR2X44P_INSTALL_PATH=/ti/mcu_plus_sdk_awr2x44p_10_01_00_04
      export MCU_PLUS_AWR2544_INSTALL_PATH=/ti/mcu_plus_sdk_awr2544_10_01_00_05
      export MMWAVE_AWR294X_DFP_INSTALL_PATH=/ti/mmwave_dfp_02_04_18_01
      export AWR294X_RADARSS_IMAGE_BIN=/ti/mmwave_dfp_02_04_18_01/firmware/radarss/xwr29xx_radarss_metarprc.bin
      export C66x_DSPLIB_INSTALL_PATH=/ti/dsplib_c66x_3_4_0_0
      export C66x_MATHLIB_INSTALL_PATH=/ti/mathlib_c66x_3_1_2_1

      DEMO_DIR=\"\$SDK_DIR/ti/demo/awr294x/${DEMO}\"
      [ -d \"\$DEMO_DIR\" ] || { echo \"Demo directory not found: \$DEMO_DIR\"; ls \"\$SDK_DIR/ti/demo/awr294x/\"; exit 1; }
      cd \"\$DEMO_DIR\"
      make clean
      make mmwDemoTDM
      echo '✓ Built firmware artefacts:'
      find . -name '*.appimage' -o -name '*.xer5f' -o -name '*.xe66' -o -name '*.bin' | head -20
    "
    ;;

  rust)
    echo "→ Building Rust firmware for Cortex-R5F (armv7r-none-eabihf)…"
    # The Rust build is fast enough to run natively on the host with rustup's
    # cross target installed, so we skip Docker here. Fall back to Docker if
    # the toolchain is missing.
    if command -v rustup >/dev/null 2>&1 && rustup target list --installed | grep -q armv7r-none-eabihf; then
      (
        cd rust/firmware-r5f
        cargo build --release
      )
    else
      docker compose -f docker/docker-compose.yml run --rm sdk bash -lc "
        cd /workspace/rust/firmware-r5f && cargo build --release
      "
    fi
    ;;

  clean)
    echo "→ Cleaning build artefacts…"
    rm -rf rust/target
    docker compose -f docker/docker-compose.yml run --rm sdk bash -lc "
      SDK_DIR=\$(ls -d /ti/mmwave_mcuplus_sdk_* 2>/dev/null | head -n1 || true)
      [ -n \"\$SDK_DIR\" ] && cd \"\$SDK_DIR/ti/demo/awr2944\" && find . -name Makefile -execdir make clean \\; || true
    "
    ;;

  *)
    cat <<EOF
Usage: $0 <mode> [args]

Modes:
  ti <demo>   Build a TI-SDK C demo (default: mmw_demo).
  rust        Build the no_std Rust R5F firmware at rust/firmware-r5f/.
  clean       Remove Rust and TI build products.

Example:
  $0 ti mmw_demo
  $0 rust
EOF
    exit 2
    ;;
esac
