#!/usr/bin/env bash
# ============================================================================
# flash-uniflash.sh
# Command-line wrapper around TI's UniFlash CLI (dslite.sh) for the AWR2944.
#
# Prerequisites:
#   - UniFlash 8.x or newer installed in /opt/ti/uniflash_* (Linux) or
#     /Applications/ti/uniflash_* (macOS).
#   - The AWR2944 must be in SOP (Sense-On-Power) flashing mode — typically
#     means SOP[2:0] = 010 (check the EVM silkscreen for jumper positions).
#
# Usage:
#   ./scripts/flash-uniflash.sh <path-to-image.bin>
# ============================================================================

set -euo pipefail

BIN="${1:-}"
[[ -f "${BIN}" ]] || { echo "Usage: $0 <firmware.bin>" >&2; exit 2; }

# ----- Locate dslite.sh ------------------------------------------------------
case "$(uname -s)" in
  Darwin)
    UNIFLASH_GLOB=(/Applications/ti/uniflash_*/dslite.sh)
    ;;
  Linux)
    UNIFLASH_GLOB=(/opt/ti/uniflash_*/dslite.sh "${HOME}/ti/uniflash_*/dslite.sh")
    ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2; exit 1;;
esac

DSLITE=""
for candidate in "${UNIFLASH_GLOB[@]}"; do
  for real in $candidate; do
    if [[ -x "${real}" ]]; then DSLITE="${real}"; break 2; fi
  done
done

if [[ -z "${DSLITE}" ]]; then
  cat <<EOF >&2
UniFlash (dslite.sh) not found.

Install UniFlash 8.x from:
  https://www.ti.com/tool/UNIFLASH
After install, re-run this script.
EOF
  exit 1
fi

echo "→ Using ${DSLITE}"

# ----- Pick the AWR2944 target config ---------------------------------------
# TI ships pre-built .ccxml files keyed off the debug probe; the AWR2944
# EVM uses the XDS110-based one below. If you use an external XDS560 pod,
# substitute the matching .ccxml.
TARGET_CFG="$(dirname "${DSLITE}")/user_files/configs/AWR2944_XDS110_USB.ccxml"
[[ -f "${TARGET_CFG}" ]] || { echo "Missing target ccxml: ${TARGET_CFG}" >&2; exit 1; }

"${DSLITE}" --mode flash \
  -c "${TARGET_CFG}" \
  -l "$(dirname "${DSLITE}")/user_files/logs/flash.log" \
  -f "${BIN}"

echo "✓ Flash complete."
echo "  Power-cycle the EVM with SOP[2:0] = 001 to boot from flash."
