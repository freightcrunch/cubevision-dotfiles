#!/usr/bin/env bash
# ============================================================================
# install-ti-sdk.sh
# Runs inside the Docker image (or can be invoked manually on an x86_64 Linux
# host). Expects TI installers mounted / present at /installers:
#
#   /installers/mmwave_mcuplus_sdk_<ver>-Linux-x86-Install.bin
#   /installers/ti_cgt_armllvm_<ver>_linux-x64_installer.bin
#   /installers/ti_cgt_c6000_<ver>_linux-x64_installer.bin
#   /installers/sysconfig-<ver>-setup.run
#
# Because TI gates downloads behind click-through EULAs, we cannot curl them
# from inside the image. Download once on the host, put them alongside
# ../installers/, and run:
#   docker compose run --rm sdk /opt/scripts/install-ti-sdk.sh
# ============================================================================

set -euo pipefail

log()  { printf '\033[1;34m[install-ti-sdk]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

INSTALLERS=/installers
TI_PREFIX=/ti

[[ -d "${INSTALLERS}" ]] || die "No /installers directory mounted. See docker-compose.yml."

shopt -s nullglob

# ---- MMWAVE-MCUPLUS-SDK ----------------------------------------------------
SDK_INSTALLER=(${INSTALLERS}/mmwave_mcuplus_sdk_*-Linux-x86-Install.bin)
if [[ ${#SDK_INSTALLER[@]} -eq 0 ]]; then
  die "No MMWAVE-MCUPLUS-SDK installer found under ${INSTALLERS}. Expected mmwave_mcuplus_sdk_*-Linux-x86-Install.bin"
fi

log "Installing MMWAVE-MCUPLUS-SDK from ${SDK_INSTALLER[0]}"
cp "${SDK_INSTALLER[0]}" /tmp/sdk_installer.bin
chmod +x /tmp/sdk_installer.bin
# The TI InstallJammer installer may exit non-zero due to sub-component
# post-install failures (e.g. mathlib under QEMU). The core SDK files are
# typically extracted before the post-install hooks run, so we tolerate the
# error and verify the installation afterwards.
if ! /tmp/sdk_installer.bin --mode unattended --prefix "${TI_PREFIX}"; then
  log "WARNING: Installer exited non-zero. Checking if core SDK was extracted..."
fi
rm -f /tmp/sdk_installer.bin

# Verify the SDK directory exists
SDK_DIR=(${TI_PREFIX}/mmwave_mcuplus_sdk_*)
if [[ ${#SDK_DIR[@]} -eq 0 ]]; then
  die "SDK installation failed — no mmwave_mcuplus_sdk_* directory found under ${TI_PREFIX}."
fi
log "SDK directory found: ${SDK_DIR[0]}"

# ---- TI-CGT-ARMLLVM (tiarmclang — R5F compiler) ----------------------------
CGT_ARM_INSTALLER=(${INSTALLERS}/ti_cgt_armllvm_*_linux-x64_installer.bin)
if [[ ${#CGT_ARM_INSTALLER[@]} -gt 0 ]]; then
  log "Installing TI-CGT-ARMLLVM from ${CGT_ARM_INSTALLER[0]}"
  cp "${CGT_ARM_INSTALLER[0]}" /tmp/cgt_arm_installer.bin
  chmod +x /tmp/cgt_arm_installer.bin
  if ! /tmp/cgt_arm_installer.bin --mode unattended --prefix "${TI_PREFIX}"; then
    log "WARNING: TI-CGT-ARMLLVM installer exited non-zero."
  fi
  rm -f /tmp/cgt_arm_installer.bin
else
  log "SKIP: No TI-CGT-ARMLLVM installer found (ti_cgt_armllvm_*_linux-x64_installer.bin)"
fi

# ---- TI-CGT-C6000 (cl6x — C66x DSP compiler) ------------------------------
CGT_C6X_INSTALLER=(${INSTALLERS}/ti_cgt_c6000_*_linux-x64_installer.bin)
if [[ ${#CGT_C6X_INSTALLER[@]} -gt 0 ]]; then
  log "Installing TI-CGT-C6000 from ${CGT_C6X_INSTALLER[0]}"
  cp "${CGT_C6X_INSTALLER[0]}" /tmp/cgt_c6x_installer.bin
  chmod +x /tmp/cgt_c6x_installer.bin
  if ! /tmp/cgt_c6x_installer.bin --mode unattended --prefix "${TI_PREFIX}"; then
    log "WARNING: TI-CGT-C6000 installer exited non-zero."
  fi
  rm -f /tmp/cgt_c6x_installer.bin
else
  log "SKIP: No TI-CGT-C6000 installer found (ti_cgt_c6000_*_linux-x64_installer.bin)"
fi

# ---- SysConfig -------------------------------------------------------------
SYSCONFIG_INSTALLER=(${INSTALLERS}/sysconfig-*-setup.run ${INSTALLERS}/sysconfig-*.run)
found_sysconfig=""
for sc in "${SYSCONFIG_INSTALLER[@]}"; do
  [[ -f "$sc" ]] && found_sysconfig="$sc" && break
done
if [[ -n "${found_sysconfig}" ]]; then
  log "Installing SysConfig from ${found_sysconfig}"
  cp "${found_sysconfig}" /tmp/sysconfig_installer.run
  chmod +x /tmp/sysconfig_installer.run
  if ! /tmp/sysconfig_installer.run --mode unattended --prefix "${TI_PREFIX}/sysconfig_1.23.0"; then
    log "WARNING: SysConfig installer exited non-zero."
  fi
  rm -f /tmp/sysconfig_installer.run
else
  log "SKIP: No SysConfig installer found (sysconfig-*-setup.run)"
fi

# ---- Path fixup for setenv.mak compatibility --------------------------------
# The mmwave SDK setenv.mak expects:
#   R5F_CLANG_INSTALL_PATH  = /ti/           -> /ti/bin/tiarmclang
#   C66X_CODEGEN_INSTALL_PATH = /ti/         -> /ti/bin/cl6x
# But TI installers create versioned subdirectories. Symlink bin/ to /ti/bin/
# if the compilers landed in subdirectories.
if [[ ! -f "${TI_PREFIX}/bin/tiarmclang" ]]; then
  ARM_DIR=(${TI_PREFIX}/ti-cgt-armllvm_*/bin/tiarmclang)
  if [[ ${#ARM_DIR[@]} -gt 0 ]]; then
    ARM_BASE=$(dirname "$(dirname "${ARM_DIR[0]}")")
    log "Symlinking ARM Clang: ${ARM_BASE}/bin -> ${TI_PREFIX}/bin (tiarmclang)"
    mkdir -p "${TI_PREFIX}/bin"
    for f in "${ARM_BASE}/bin/"*; do
      ln -sf "$f" "${TI_PREFIX}/bin/$(basename "$f")" 2>/dev/null || true
    done
  fi
fi
if [[ ! -f "${TI_PREFIX}/bin/cl6x" ]]; then
  C6X_DIR=(${TI_PREFIX}/ti-cgt-c6000_*/bin/cl6x)
  if [[ ${#C6X_DIR[@]} -gt 0 ]]; then
    C6X_BASE=$(dirname "$(dirname "${C6X_DIR[0]}")")
    log "Symlinking C6000: ${C6X_BASE}/bin -> ${TI_PREFIX}/bin (cl6x)"
    mkdir -p "${TI_PREFIX}/bin"
    for f in "${C6X_BASE}/bin/"*; do
      ln -sf "$f" "${TI_PREFIX}/bin/$(basename "$f")" 2>/dev/null || true
    done
  fi
fi

# ---- Report ---------------------------------------------------------------
log "Installed TI components under ${TI_PREFIX}:"
ls -la "${TI_PREFIX}"
echo ""
log "Compiler check:"
for tool in tiarmclang cl6x arm-none-eabi-gcc rustc; do
  if command -v "$tool" >/dev/null 2>&1 || [[ -x "${TI_PREFIX}/bin/$tool" ]]; then
    log "  $tool: found"
  else
    log "  $tool: MISSING"
  fi
done
if [[ -d "${TI_PREFIX}/sysconfig_1.23.0" ]]; then
  log "  SysConfig: ${TI_PREFIX}/sysconfig_1.23.0"
else
  log "  SysConfig: MISSING"
fi
