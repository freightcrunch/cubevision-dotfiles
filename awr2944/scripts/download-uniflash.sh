#!/usr/bin/env bash
# ============================================================================
# download-uniflash.sh
# Downloads and optionally installs TI UniFlash for the AWR2944 workflow.
#
# Supports:
#   macOS          (Intel & Apple Silicon — runs under Rosetta 2)
#   Linux x86_64   (native)
#   Linux arm64    (x86_64 binary via Docker container / qemu-user-static)
#   Windows        (x86_64 — download only; run the .exe manually)
#
# Usage:
#   ./scripts/download-uniflash.sh [OPTIONS]
#
# Options:
#   --platform <PLATFORM>   One of: auto, macos, linux, linux-arm64, windows
#                           Default: auto (detect from current host)
#   --install               Download AND install (default: download only)
#   --prefix <PATH>         Override the installation directory
#   --help                  Show this help
#
# Examples:
#   ./scripts/download-uniflash.sh                          # download for current host
#   ./scripts/download-uniflash.sh --install                # download + install
#   ./scripts/download-uniflash.sh --platform linux-arm64   # download Linux x86_64
#                                                           # installer (for Docker)
#   ./scripts/download-uniflash.sh --platform windows       # download .exe
# ============================================================================

set -euo pipefail

UNIFLASH_VERSION="9.5.0"
UNIFLASH_BUILD="5651"
BASE_URL="https://dr-download.ti.com/software-development/software-programming-tool/MD-QeJBJLj8gq/${UNIFLASH_VERSION}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
INSTALLERS_DIR="${PROJECT_DIR}/installers"

# ----- Parse arguments ------------------------------------------------------
DO_INSTALL=false
PLATFORM="auto"
INSTALL_PREFIX_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)    DO_INSTALL=true; shift ;;
    --platform)   PLATFORM="${2:-}"; shift 2 ;;
    --prefix)     INSTALL_PREFIX_OVERRIDE="${2:-}"; shift 2 ;;
    --help|-h)
      sed -n '2,/^# ====/{ /^# ====/d; s/^# \?//p; }' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "${INSTALLERS_DIR}"

# ----- Resolve platform -----------------------------------------------------
if [[ "${PLATFORM}" == "auto" ]]; then
  HOST_OS="$(uname -s)"
  HOST_ARCH="$(uname -m)"
  case "${HOST_OS}" in
    Darwin)                         PLATFORM="macos" ;;
    Linux)
      if [[ "${HOST_ARCH}" == "aarch64" || "${HOST_ARCH}" == "arm64" ]]; then
        PLATFORM="linux-arm64"
      else
        PLATFORM="linux"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT) PLATFORM="windows" ;;
    *) echo "ERROR: Cannot auto-detect platform ($(uname -s) / $(uname -m))." >&2
       echo "       Specify --platform macos|linux|linux-arm64|windows" >&2
       exit 1 ;;
  esac
fi

case "${PLATFORM}" in
  macos)
    FILENAME="uniflash_sl.${UNIFLASH_VERSION}.${UNIFLASH_BUILD}.dmg"
    INSTALL_PREFIX="${INSTALL_PREFIX_OVERRIDE:-/Applications/ti}"
    ;;
  linux|linux-x86_64)
    FILENAME="uniflash_sl.${UNIFLASH_VERSION}.${UNIFLASH_BUILD}.run"
    INSTALL_PREFIX="${INSTALL_PREFIX_OVERRIDE:-${HOME}/ti}"
    ;;
  linux-arm64|linux-aarch64)
    # UniFlash is x86_64-only; on arm64 Linux it runs inside the Docker
    # container via qemu-user-static, or on macOS Docker Desktop via Rosetta.
    FILENAME="uniflash_sl.${UNIFLASH_VERSION}.${UNIFLASH_BUILD}.run"
    INSTALL_PREFIX="${INSTALL_PREFIX_OVERRIDE:-/ti}"
    ;;
  windows|win|win64)
    FILENAME="uniflash_sl.${UNIFLASH_VERSION}.${UNIFLASH_BUILD}.exe"
    INSTALL_PREFIX="${INSTALL_PREFIX_OVERRIDE:-C:\\ti}"
    ;;
  *)
    echo "ERROR: Unknown platform '${PLATFORM}'." >&2
    echo "       Choose: macos, linux, linux-arm64, windows" >&2
    exit 1
    ;;
esac

DOWNLOAD_URL="${BASE_URL}/${FILENAME}"
TARGET="${INSTALLERS_DIR}/${FILENAME}"

echo "Platform : ${PLATFORM}"
echo "Installer: ${FILENAME}"
echo ""

# ----- Download -------------------------------------------------------------
if [[ -f "${TARGET}" ]]; then
  echo "→ Already downloaded: ${TARGET}"
else
  echo "→ Downloading UniFlash ${UNIFLASH_VERSION}…"
  echo "  URL: ${DOWNLOAD_URL}"
  curl -fSL --progress-bar -o "${TARGET}" "${DOWNLOAD_URL}"
  echo "→ Saved to: ${TARGET}"
fi

# ----- Install (optional) ---------------------------------------------------
if [[ "${DO_INSTALL}" != true ]]; then
  echo ""
  echo "Download complete. To install, re-run with --install:"
  echo "  $0 --platform ${PLATFORM} --install"
  echo ""
  echo "Or install manually:"
  case "${PLATFORM}" in
    macos)
      echo "  open ${TARGET}"
      echo "  # Then drag UniFlash to ${INSTALL_PREFIX}/"
      ;;
    linux|linux-x86_64)
      echo "  chmod +x ${TARGET}"
      echo "  ${TARGET} --mode unattended --prefix ${INSTALL_PREFIX}/uniflash_${UNIFLASH_VERSION}"
      ;;
    linux-arm64|linux-aarch64)
      echo "  # UniFlash is x86_64-only. Install inside the Docker container:"
      echo "  docker compose -f docker/docker-compose.yml run --rm sdk bash -c '"
      echo "    cp /installers/${FILENAME} /tmp/uniflash_installer.run"
      echo "    chmod +x /tmp/uniflash_installer.run"
      echo "    /tmp/uniflash_installer.run --mode unattended --prefix ${INSTALL_PREFIX}/uniflash_${UNIFLASH_VERSION}"
      echo "    rm /tmp/uniflash_installer.run'"
      ;;
    windows|win|win64)
      echo "  Run ${TARGET} and follow the installer prompts."
      ;;
  esac
  exit 0
fi

echo ""
echo "→ Installing UniFlash ${UNIFLASH_VERSION}…"

case "${PLATFORM}" in
  macos)
    # Mount the DMG, copy the app, unmount
    MOUNT_POINT=$(hdiutil attach "${TARGET}" -nobrowse -noverify -noautoopen 2>/dev/null | grep "/Volumes/" | tail -1 | awk -F'\t' '{print $NF}')
    if [[ -z "${MOUNT_POINT}" ]]; then
      echo "ERROR: Failed to mount ${TARGET}" >&2
      echo "Try installing manually: open ${TARGET}" >&2
      exit 1
    fi
    echo "  Mounted at: ${MOUNT_POINT}"

    mkdir -p "${INSTALL_PREFIX}"
    UNIFLASH_APP=$(find "${MOUNT_POINT}" -maxdepth 2 -name "*.app" -type d 2>/dev/null | head -1)
    if [[ -n "${UNIFLASH_APP}" ]]; then
      echo "  Copying $(basename "${UNIFLASH_APP}") to ${INSTALL_PREFIX}/"
      cp -R "${UNIFLASH_APP}" "${INSTALL_PREFIX}/"
    else
      UNIFLASH_PKG=$(find "${MOUNT_POINT}" -maxdepth 2 -name "*.pkg" 2>/dev/null | head -1)
      if [[ -n "${UNIFLASH_PKG}" ]]; then
        echo "  Running installer package…"
        sudo installer -pkg "${UNIFLASH_PKG}" -target /
      else
        echo "  Copying UniFlash contents to ${INSTALL_PREFIX}/uniflash_${UNIFLASH_VERSION}/"
        mkdir -p "${INSTALL_PREFIX}/uniflash_${UNIFLASH_VERSION}"
        cp -R "${MOUNT_POINT}/"* "${INSTALL_PREFIX}/uniflash_${UNIFLASH_VERSION}/" 2>/dev/null || true
      fi
    fi

    hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null || true
    echo "  Unmounted DMG."
    ;;

  linux|linux-x86_64)
    chmod +x "${TARGET}"
    UNIFLASH_DIR="${INSTALL_PREFIX}/uniflash_${UNIFLASH_VERSION}"
    mkdir -p "${INSTALL_PREFIX}"
    if ! "${TARGET}" --mode unattended --prefix "${UNIFLASH_DIR}"; then
      echo "WARNING: Installer exited non-zero (may still have installed)."
    fi
    ;;

  linux-arm64|linux-aarch64)
    # UniFlash is x86_64-only — install inside the Docker container where
    # qemu-user-static (or Rosetta on Docker Desktop) can run it.
    echo "  Installing inside Docker container (x86_64 via emulation)…"
    COMPOSE_FILE="${PROJECT_DIR}/docker/docker-compose.yml"
    if [[ ! -f "${COMPOSE_FILE}" ]]; then
      echo "ERROR: ${COMPOSE_FILE} not found." >&2
      echo "       Build the Docker image first (see README)." >&2
      exit 1
    fi
    docker compose -f "${COMPOSE_FILE}" run --rm sdk bash -c "
      set -e
      cp /installers/${FILENAME} /tmp/uniflash_installer.run
      chmod +x /tmp/uniflash_installer.run
      if ! /tmp/uniflash_installer.run --mode unattended --prefix ${INSTALL_PREFIX}/uniflash_${UNIFLASH_VERSION}; then
        echo 'WARNING: Installer exited non-zero (may still have installed).'
      fi
      rm -f /tmp/uniflash_installer.run
      echo ''
      if [[ -x ${INSTALL_PREFIX}/uniflash_${UNIFLASH_VERSION}/dslite.sh ]]; then
        echo 'UniFlash installed inside container at ${INSTALL_PREFIX}/uniflash_${UNIFLASH_VERSION}/'
      else
        echo 'WARNING: dslite.sh not found after install.'
        ls ${INSTALL_PREFIX}/uniflash_${UNIFLASH_VERSION}/ 2>/dev/null || true
      fi
    "
    ;;

  windows|win|win64)
    echo "  Windows installer must be run manually (GUI):"
    echo "  ${TARGET}"
    exit 0
    ;;
esac

# ----- Verify ---------------------------------------------------------------
echo ""
echo "→ Verifying installation…"

DSLITE=""
case "${PLATFORM}" in
  macos)
    for d in "${INSTALL_PREFIX}"/uniflash_*/dslite.sh "${INSTALL_PREFIX}"/UniFlash.app/Contents/*/dslite.sh; do
      [[ -x "$d" ]] 2>/dev/null && DSLITE="$d" && break
    done
    ;;
  linux|linux-x86_64)
    for d in "${INSTALL_PREFIX}"/uniflash_*/dslite.sh; do
      [[ -x "$d" ]] 2>/dev/null && DSLITE="$d" && break
    done
    ;;
  linux-arm64|linux-aarch64)
    # Verification already happened inside the Docker run above.
    # Print the flash command for this platform.
    echo "✓ To flash from the Docker container:"
    echo "  docker compose -f docker/docker-compose.yml run --rm \\"
    echo "    --device /dev/ttyACM0 --device /dev/ttyACM1 \\"
    echo "    sdk ${INSTALL_PREFIX}/uniflash_${UNIFLASH_VERSION}/dslite.sh \\"
    echo "    --mode flash \\"
    echo "    -c ${INSTALL_PREFIX}/uniflash_${UNIFLASH_VERSION}/user_files/configs/AWR2944_XDS110_USB.ccxml \\"
    echo "    -f /workspace/output/awr2944_mmw_demoTDM.appimage"
    exit 0
    ;;
  windows|win|win64)
    echo "Run the .exe installer, then flash from UniFlash GUI or CLI."
    exit 0
    ;;
esac

if [[ -n "${DSLITE}" ]]; then
  echo "✓ UniFlash installed — dslite.sh found at:"
  echo "  ${DSLITE}"
  echo ""
  echo "Flash the AWR2944 EVM with:"
  echo "  ./scripts/flash-uniflash.sh output/awr2944_mmw_demoTDM.appimage"
else
  echo "⚠ Could not verify dslite.sh location."
  echo "  UniFlash may need to be opened once from the GUI first."
  echo "  Check: ls ${INSTALL_PREFIX}/uniflash_*/ or /Applications/ti/"
fi
