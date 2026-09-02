#!/usr/bin/env bash
# ------------------------------------------------------------------
# update-jetpack.sh — check for and update to the latest JetPack
#
# Detects the installed L4T/JetPack version, looks up the latest
# upstream release, and either:
#   - same major version → apt dist-upgrade path (in-place)
#   - different major    → prints SDK Manager reflash instructions
#     (JetPack 7.x / L4T 39.x / Ubuntu 24.04 requires a reflash)
#
# Usage:  ./scripts/update-jetpack.sh [--check | --apply | --post]
#   --check  report current vs latest (default, read-only)
#   --apply  run the in-place apt upgrade (minor releases only)
#   --post   post-update dependency sync (jtop patch, CUDA check)
#
# Ref: NVIDIA forums guide "Jetson Orin Nano Super on JetPack 7.2"
#      (JetPack 7.2.1 = L4T 39.2.1, CUDA 13.2.1, cuDNN 9.20,
#       TensorRT 10.16.2, kernel 6.8, Ubuntu 24.04)
# ------------------------------------------------------------------
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; }
section() { echo -e "\n${BLUE}━━━ $* ━━━${NC}"; }

# Known L4T → JetPack map (add entries as NVIDIA releases them).
# Falls back to this when offline; also mirrors patch-jtop-jetpack.sh.
declare -A L4T_TO_JP=(
    ["39.2.1"]="7.2.1" ["39.2"]="7.2" ["39.1"]="7.1.1" ["39.0"]="7.1"
    ["38.4"]="7.1" ["38.3"]="7.0.1" ["38.2"]="7.0"
    ["36.4.7"]="6.2.1" ["36.4.3"]="6.2" ["36.4"]="6.1.1" ["36.4.0"]="6.1"
    ["36.3"]="6.0" ["35.6.1"]="5.1.5" ["35.6.0"]="5.1.4" ["35.4.1"]="5.1.2"
)
FALLBACK_LATEST="7.2.1"

# L4T release series → Ubuntu base, CUDA, kernel (for status display)
declare -A SERIES_INFO=(
    ["39"]="JP7 · Ubuntu 24.04 · CUDA 13.2 · kernel 6.8"
    ["38"]="JP7 · Ubuntu 24.04 · CUDA 13.0 · kernel 6.8"
    ["36"]="JP6 · Ubuntu 22.04 · CUDA 12.6 · kernel 5.15"
    ["35"]="JP5 · Ubuntu 20.04 · CUDA 11.4 · kernel 5.10"
)

# --- Detect installed L4T version ---------------------------------
get_current_l4t() {
    local v=""
    if command -v dpkg-query &>/dev/null; then
        v=$(dpkg-query -W -f='${Version}' nvidia-l4t-core 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?' || true)
    fi
    if [[ -z "$v" && -f /etc/nv_tegra_release ]]; then
        v=$(grep -oE 'REVISION: [0-9.]+' /etc/nv_tegra_release | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' || true)
        # nv_tegra_release revision omits trailing ".0" for x.0 releases
        [[ "$v" == *.* && "$v" != *.*.* ]] && v="${v}.0"
    fi
    echo "$v"
}

get_current_jp() {
    local l4t="$1"
    if [[ -n "${L4T_TO_JP[$l4t]:-}" ]]; then
        echo "${L4T_TO_JP[$l4t]}"
    else
        # ask installed jetson-stats if it knows
        python3 -c "
from jtop.core.jetson_variables import NVIDIA_JETPACK
import re
l4t = re.search(r'# R(\d+) \(release\), REVISION: ([0-9.]+)', open('/etc/nv_tegra_release').read())
v = l4t.group(1) + '.' + l4t.group(2)
v = v if v in NVIDIA_JETPACK else v.rstrip('.0') if v.endswith('.0') and v.rstrip('.0') in NVIDIA_JETPACK else v
print(NVIDIA_JETPACK.get(v, 'unknown'))" 2>/dev/null || echo "unknown"
    fi
}

# --- Look up latest upstream JetPack ------------------------------
get_latest_jp() {
    local v=""
    # Primary: NVIDIA JetPack downloads page
    if command -v curl &>/dev/null; then
        v=$(curl -fsSL --max-time 20 https://developer.nvidia.com/embedded/jetpack/downloads 2>/dev/null \
            | grep -oE 'JetPack [0-9]+(\.[0-9]+)+' | head -1 | grep -oE '[0-9]+(\.[0-9]+)+' || true)
    fi
    # Fallback: hardcoded known-latest
    if [[ -z "$v" ]]; then
        warn "Could not reach NVIDIA (offline?). Using known-latest: $FALLBACK_LATEST"
        v="$FALLBACK_LATEST"
    fi
    echo "$v"
}

major_of() { echo "$1" | cut -d. -f1; }

# --- Reflash instructions (major version change) ------------------
print_reflash_instructions() {
    local latest_jp="$1" latest_l4t="$2"
    section "Major Upgrade — Reflash Required"
    warn "In-place upgrade across JetPack majors is NOT supported."
    echo
    echo "  Target: JetPack $latest_jp (L4T $latest_l4t, Ubuntu 24.04, CUDA 13.2, kernel 6.8)"
    echo
    echo "  NOTE: JetPack 7.2+ ships NO SD-card image for the Orin Nano dev kit —"
    echo "        flash via SDK Manager or the unified ISO from an x86_64 host."
    echo
    echo "  1. On an Ubuntu 22.04/24.04 x86_64 host, install SDK Manager:"
    echo "       https://developer.nvidia.com/sdk-manager"
    echo "  2. Enter recovery mode (reference carrier has no buttons):"
    echo "       - Unplug DC power, wait 10 s"
    echo "       - Short pins 9-10 of button header J14 (near DC jack)"
    echo "       - Apply DC power while shorted; release after 2-3 s"
    echo "     Verify on host:  lsusb | grep -i nvidia   # NVIDIA Corp. APX"
    echo "  3. SDK Manager → target 'Jetson Orin Nano [8GB developer kit]'"
    echo "     (module P3767-0005, carrier P3768-0000), storage NVMe."
    echo "  4. Fill in Pre-Config (user/pass/hostname) — do NOT skip it."
    echo "  5. First run: uncheck 'Jetson SDK Components'; flash base OS only."
    echo "  6. After reboot, install CUDA/cuDNN/TensorRT components in a second pass."
    echo
    echo "  After the reflash, re-run this script with --post to sync deps."
}

# --- In-place apt upgrade (same major version) ---------------------
apply_apt_upgrade() {
    section "In-Place Upgrade (apt)"
    if ! grep -rq '^deb.*repo.download.nvidia.com/jetson' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        warn "NVIDIA L4T apt source is disabled/missing — re-enabling (r$(major_of "$(get_current_l4t)") series)."
        sudo mv /etc/apt/sources.list.d/nvidia-l4t-apt-source.list.save \
                 /etc/apt/sources.list.d/nvidia-l4t-apt-source.list 2>/dev/null || \
            warn "Could not re-enable nvidia-l4t-apt-source.list — enable it manually."
    fi
    sudo apt-get update
    sudo apt-get dist-upgrade -y
    info "Upgrade complete. Reboot to activate the new kernel/modules."
    echo "  sudo reboot"
    info "After reboot:  ./scripts/update-jetpack.sh --post"
}

# --- Post-update dependency sync -----------------------------------
post_update() {
    section "Post-Update Dependency Sync"
    local l4t; l4t="$(get_current_l4t)"
    local jp;  jp="$(get_current_jp "$l4t")"
    info "Now on: L4T $l4t / JetPack $jp"

    # 1. jetson-stats / jtop — reinstall + patch lookup table for new L4T
    info "Updating jetson-stats (jtop) ..."
    sudo pip3 install -U jetson-stats --break-system-packages 2>/dev/null || \
        sudo pip3 install -U jetson-stats || warn "jetson-stats update failed"
    if [[ -f "$DOTFILES/scripts/patch-jtop-jetpack.sh" ]]; then
        sudo bash "$DOTFILES/scripts/patch-jtop-jetpack.sh" || warn "jtop patch failed (may be unneeded)"
    fi

    # 2. CUDA toolchain sanity
    section "Toolchain Check"
    if command -v nvcc &>/dev/null; then
        info "nvcc: $(nvcc --version | tail -1)"
    else
        warn "nvcc not found — install CUDA via SDK components or apt:"
        warn "  sudo apt install nvidia-jetpack"
    fi
    python3 -c "import ctypes; ctypes.CDLL('libcudnn.so')" 2>/dev/null && info "cuDNN: loadable" || warn "cuDNN not loadable"

    # 3. From-source tools must be rebuilt against the new CUDA
    section "Rebuild From-Source Tools"
    warn "Anything compiled against the old CUDA must be rebuilt:"
    for tool in ~/llama.cpp ~/stable-diffusion.cpp; do
        [[ -d "$tool" ]] && echo "  cd $tool && rm -rf build && cmake -B build -DGGML_CUDA=ON -DSD_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=87 && cmake --build build -j\$(nproc)"
    done
    echo "  (Prebuilt CUDA 12.6 binaries — dustynv containers, Ollama prebuilt —"
    echo "   do NOT work on JetPack 7.x; build from source with sm_87 kernels.)"

    # 4. Power/perf settings per the forum guide
    section "Performance Settings (per forum guide)"
    echo "  sudo nvpmodel -m 2        # MAXN_SUPER (check IDs: nvpmodel -q)"
    echo "  sudo jetson_clocks        # pin clocks (make persistent via systemd)"
    info "Done."
}

# --- Main ----------------------------------------------------------
MODE="${1:---check}"

CURRENT_L4T="$(get_current_l4t)"
CURRENT_JP="$(get_current_jp "$CURRENT_L4T")"
LATEST_JP="$(get_latest_jp)"
# latest L4T series from latest JetPack major (7.2.1 → 39.2.1)
LATEST_L4T="$([[ "$(major_of "$LATEST_JP")" == 7 ]] && echo "39.2.1" || echo "unknown")"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  JetPack Update Checker — Jetson Orin Nano Super             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
info "Installed:  JetPack $CURRENT_JP  (L4T $CURRENT_L4T)"
info "  ${SERIES_INFO[$(major_of "$CURRENT_L4T")]:-unknown series}"
info "Latest:     JetPack $LATEST_JP  (L4T $LATEST_L4T)"

case "$MODE" in
    --check)
        if [[ "$(major_of "$CURRENT_JP")" == "$(major_of "$LATEST_JP")" ]]; then
            if [[ "$CURRENT_JP" == "$LATEST_JP" ]]; then
                info "Up to date."
            else
                warn "Minor update available → run with --apply"
            fi
        else
            print_reflash_instructions "$LATEST_JP" "$LATEST_L4T"
        fi
        ;;
    --apply)
        if [[ "$(major_of "$CURRENT_JP")" != "$(major_of "$LATEST_JP")" ]]; then
            error "Cannot apt-upgrade across majors (6.x → 7.x). Reflash required:"
            print_reflash_instructions "$LATEST_JP" "$LATEST_L4T"
            exit 1
        fi
        apply_apt_upgrade
        ;;
    --post) post_update ;;
    *) error "Unknown option: $MODE"; exit 1 ;;
esac
