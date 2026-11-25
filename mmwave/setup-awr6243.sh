#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  mmWave Radar Setup — AWR6243 / IWR6243 (57–64 GHz front end)        ║
# ║                                                                      ║
# ║  The xWR6243 is a FRONT-END-ONLY MMIC: no R4F MCU, no C674x DSP,     ║
# ║  no on-chip user memory, no UART CLI and no USB bridge. The host     ║
# ║  does everything — it is the SPI master, it downloads the device     ║
# ║  firmware after every reset, and it captures raw ADC samples over    ║
# ║  MIPI CSI-2 (LVDS is a debug interface only).                        ║
# ║                                                                      ║
# ║  This script prepares the HOST (Jetson / Linux SBC):                 ║
# ║    spidev + GPIO access · udev rules · groups · DFP staging ·        ║
# ║    Python tooling · CSI-2 / DCA1000 capture readiness                ║
# ║                                                                      ║
# ║  Usage:                                                              ║
# ║    bash mmwave/setup-awr6243.sh                                      ║
# ║    bash mmwave/setup-awr6243.sh --check                              ║
# ║    bash mmwave/setup-awr6243.sh --dfp ~/Downloads/mmwave_dfp_*.zip   ║
# ║    bash mmwave/setup-awr6243.sh --spidev /dev/spidev1.0 --selftest   ║
# ║    bash mmwave/setup-awr6243.sh --venv /path/to/venv                 ║
# ║                                                                      ║
# ║  Datasheet: https://www.ti.com/lit/ds/symlink/iwr6243.pdf (SWRS283A) ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
MMWAVE_DIR="$DOTFILES/mmwave"
AWR6243_DIR="$MMWAVE_DIR/awr6243"
BOARD_ENV="$AWR6243_DIR/board.env"
UDEV_RULES="$MMWAVE_DIR/99-awr6243.rules"

# ─── Defaults ────────────────────────────────────────────────────────
CHECK_ONLY=false
RUN_SELFTEST=false
DFP_SOURCE=""
DFP_ROOT="${HOME}/ti/mmwave_dfp"
DFP_ROOT_OVERRIDE=""
VENV_OVERRIDE=""
SPIDEV_OVERRIDE=""
CAPTURE_OVERRIDE=""

# Latest firmware package for this device family, as published by TI.
DFP_NAME="MMWAVE-DFP-2G-60GHZ-FW"
DFP_VERSION="06.04.01.00"
DFP_URL="https://www.ti.com/tool/download/MMWAVE-DFP-2G-60GHZ-FW"

# ─── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[x]${NC} $*" >&2; }
section() { echo -e "\n${BLUE}--- $* ---${NC}"; }
detail()  { echo -e "    ${CYAN}->${NC} $*"; }

# ─── Platform detection ──────────────────────────────────────────────
detect_platform() {
    if [[ "$(uname -r)" == *microsoft* ]] || [[ "$(uname -r)" == *Microsoft* ]]; then
        PLATFORM="wsl2"
    elif [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]] || [[ -n "${WINDIR:-}" ]]; then
        PLATFORM="windows"
    else
        PLATFORM="linux"
    fi
}
detect_platform

IS_JETSON=false
if [ -r /proc/device-tree/model ] && tr -d '\0' < /proc/device-tree/model | grep -qi "jetson\|tegra"; then
    IS_JETSON=true
fi

case "$PLATFORM" in
    windows)
        DEFAULT_VENV="${USERPROFILE:-$HOME}/.venvs/radar"
        PYTHON_BIN="python"
        ;;
    *)
        DEFAULT_VENV="${HOME}/.venvs/radar"
        PYTHON_BIN="python3"
        ;;
esac

# ─── Parse arguments ────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)     CHECK_ONLY=true ;;
        --selftest)  RUN_SELFTEST=true ;;
        --dfp)       shift; DFP_SOURCE="${1:-}" ;;
        --dfp-root)  shift; DFP_ROOT_OVERRIDE="${1:-}" ;;
        --venv)      shift; VENV_OVERRIDE="${1:-}" ;;
        --spidev)    shift; SPIDEV_OVERRIDE="${1:-}" ;;
        --capture)   shift; CAPTURE_OVERRIDE="${1:-}" ;;
        --help|-h)
            echo "Usage: $0 [--check] [--selftest] [--dfp ZIP|DIR] [--dfp-root DIR]"
            echo "          [--venv PATH] [--spidev /dev/spidevB.C] [--capture csi2|dca1000]"
            echo ""
            echo "  --check       Report host readiness only (no changes)"
            echo "  --selftest    SPI loopback test (needs MOSI tied to MISO, no radar attached)"
            echo "  --dfp         Stage MMWAVE-DFP-2G-60GHZ-FW from a zip or an extracted dir"
            echo "  --dfp-root    Where the DFP is staged (default: ~/ti/mmwave_dfp)"
            echo "  --venv PATH   Python venv path (default: ~/.venvs/radar)"
            echo "  --spidev DEV  SPI master device node for the radar control link"
            echo "  --capture     Raw ADC capture path to prepare: csi2 (default) or dca1000"
            echo ""
            echo "  Detected platform: $PLATFORM (jetson: $IS_JETSON)"
            exit 0
            ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# ─── Settings: command line > board.env > built-in default ──────────
if [ -f "$BOARD_ENV" ]; then
    # shellcheck disable=SC1090
    source "$BOARD_ENV"
fi
SPIDEV="${SPIDEV_OVERRIDE:-${AWR6243_SPIDEV:-/dev/spidev0.0}}"
CAPTURE="${CAPTURE_OVERRIDE:-${AWR6243_CAPTURE:-csi2}}"
DFP_ROOT="${DFP_ROOT_OVERRIDE:-${AWR6243_DFP_ROOT:-$DFP_ROOT}}"
RADAR_VENV="${VENV_OVERRIDE:-${AWR6243_VENV:-$DEFAULT_VENV}}"
SPI_BITS="${AWR6243_SPI_BITS_PER_WORD:-16}"
SPI_SPEED="${AWR6243_SPI_SPEED_HZ:-5000000}"

if [ "$PLATFORM" = "windows" ]; then
    VENV_PYTHON="$RADAR_VENV/Scripts/python.exe"
    VENV_ACTIVATE="$RADAR_VENV/Scripts/activate"
else
    VENV_PYTHON="$RADAR_VENV/bin/python"
    VENV_ACTIVATE="$RADAR_VENV/bin/activate"
fi

# ═══════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════

find_fw_images() {
    # Device firmware images shipped in the DFP (metaImage / patch binaries).
    if [ -d "$DFP_ROOT" ]; then
        find "$DFP_ROOT" -type f \
            \( -iname "*metaimage*.bin" -o -iname "*radarss*.bin" -o -iname "*mss*.bin" \) \
            2>/dev/null | sort
    fi
}

print_dfp_instructions() {
    detail "Download $DFP_NAME $DFP_VERSION (export-controlled, needs a TI login):"
    detail "  $DFP_URL"
    detail "Then stage it:"
    detail "  bash mmwave/setup-awr6243.sh --dfp ~/Downloads/mmwave_dfp_${DFP_VERSION//./_}.zip"
    detail "The .exe is a Windows installer; the .zip unpacks on Linux."
}

# ═══════════════════════════════════════════════════════════════════════
# CHECK MODE
# ═══════════════════════════════════════════════════════════════════════

check_host_linux() {
    if [ "$IS_JETSON" = true ]; then
        section "AWR6243 host readiness (Linux, Jetson)"
    else
        section "AWR6243 host readiness (Linux)"
    fi

    # SPI master
    local spi_nodes
    spi_nodes="$(ls /dev/spidev* 2>/dev/null || true)"
    if [ -n "$spi_nodes" ]; then
        info "SPI master nodes present:"
        local node
        for node in $spi_nodes; do
            detail "$node"
        done
        if [ -e "$SPIDEV" ]; then
            info "Configured control link $SPIDEV: present"
        else
            warn "Configured control link $SPIDEV: MISSING"
        fi
    else
        warn "No /dev/spidev* nodes — the host is not an SPI master yet"
        if [ "$IS_JETSON" = true ]; then
            detail "Enable the header SPI: sudo /opt/nvidia/jetson-io/jetson-io.py"
            detail "Then: sudo modprobe spidev"
        fi
    fi

    # GPIO
    if command -v gpiodetect &>/dev/null; then
        info "libgpiod tools: installed"
        gpiodetect 2>/dev/null | while read -r line; do
            detail "$line"
        done
    else
        warn "libgpiod tools: not installed (gpiod package)"
    fi

    # udev rules + groups
    if [ -f /etc/udev/rules.d/99-awr6243.rules ]; then
        info "udev rules: INSTALLED"
    else
        warn "udev rules: NOT INSTALLED"
    fi
    local grp
    for grp in spi gpio i2c plugdev dialout; do
        if getent group "$grp" >/dev/null 2>&1; then
            if id -nG "$USER" | grep -qw "$grp"; then
                info "group $grp: $USER is a member"
            else
                warn "group $grp: $USER is NOT a member"
            fi
        fi
    done

    # Board config
    echo ""
    if [ -f "$BOARD_ENV" ]; then
        info "Board config: $BOARD_ENV"
        local unset_lines=""
        local v
        for v in NRESET SOP0 SOP1 SOP2 HOST_INTR; do
            local varname="AWR6243_LINE_$v"
            if [ -z "${!varname:-}" ]; then
                unset_lines="$unset_lines $v"
            fi
        done
        if [ -n "$unset_lines" ]; then
            warn "GPIO lines still unset:$unset_lines"
        else
            info "GPIO lines: NRESET/SOP0/SOP1/SOP2/HOST_INTR all set"
        fi
    else
        warn "Board config: not created yet ($BOARD_ENV)"
    fi

    # Firmware
    echo ""
    local images
    images="$(find_fw_images)"
    if [ -n "$images" ]; then
        info "Device firmware staged under $DFP_ROOT:"
        local img
        for img in $images; do
            detail "$(basename "$img")"
        done
    else
        warn "No device firmware found under $DFP_ROOT"
        print_dfp_instructions
    fi

    # Capture path
    echo ""
    case "$CAPTURE" in
        csi2)
            if ls /dev/video* &>/dev/null; then
                info "V4L2 capture nodes present:"
                local vid
                for vid in /dev/video*; do
                    detail "$vid"
                done
            else
                warn "No /dev/video* nodes — CSI-2 capture needs a device-tree overlay"
                detail "and a V4L2 source driver for the radar front end (see README)."
            fi
            ;;
        dca1000)
            info "DCA1000 capture selected (LVDS debug port)."
            detail "Default DCA1000 networking: FPGA 192.168.33.180, host 192.168.33.30,"
            detail "config UDP 4096, record UDP 4098 — confirm against the DCA1000 guide."
            ;;
        *) warn "Unknown capture path: $CAPTURE (want csi2 or dca1000)" ;;
    esac
}

check_host_other() {
    section "AWR6243 host readiness ($PLATFORM)"
    warn "$PLATFORM cannot be the radar's SPI master or CSI-2 receiver."
    detail "Use it for the TI tooling path instead: DFP download, DCA1000 capture,"
    detail "and post-processing. Run the host setup on the Jetson / Linux SBC."
    local images
    images="$(find_fw_images)"
    if [ -n "$images" ]; then
        info "Device firmware staged under $DFP_ROOT:"
        local img
        for img in $images; do
            detail "$(basename "$img")"
        done
    else
        warn "No device firmware found under $DFP_ROOT"
        print_dfp_instructions
    fi
}

check_python() {
    echo ""
    if [ -d "$RADAR_VENV" ] && [ -f "$VENV_PYTHON" ]; then
        info "Python venv: $RADAR_VENV"
        "$VENV_PYTHON" - <<'PY' 2>/dev/null || warn "Some radar packages are missing from the venv"
import importlib
for mod in ("numpy", "scipy", "spidev", "pyftdi", "websockets"):
    try:
        m = importlib.import_module(mod)
        print(f"    -> {mod} {getattr(m, '__version__', '')}".rstrip())
    except Exception as exc:  # noqa: BLE001
        print(f"    !! {mod}: {exc}")
PY
    else
        warn "Python venv: not found at $RADAR_VENV"
    fi
}

if [ "$CHECK_ONLY" = true ]; then
    case "$PLATFORM" in
        linux) check_host_linux ;;
        *)     check_host_other ;;
    esac
    check_python
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════
# MAIN INSTALL
# ═══════════════════════════════════════════════════════════════════════

echo "================================================================="
echo "  AWR6243 / IWR6243 host setup"
echo "  Platform: $PLATFORM (jetson: $IS_JETSON)"
echo "  Front-end-only MMIC: host SPI master + CSI-2 receiver"
echo "================================================================="
echo ""

if [ "$PLATFORM" != "linux" ]; then
    warn "Running on $PLATFORM: the SPI/GPIO/CSI-2 steps need a Linux host."
    detail "Only the firmware staging and Python steps will run here."
fi

# ─── 1. System packages ──────────────────────────────────────────────
install_packages() {
    section "1/7 -- System packages"
    if [ "$PLATFORM" != "linux" ]; then
        detail "Skipped on $PLATFORM."
        return 0
    fi
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        python3-pip python3-venv \
        gpiod libgpiod-dev \
        libftdi1-2 libftdi1-dev \
        usbutils i2c-tools v4l-utils \
        unzip device-tree-compiler \
        || warn "Some packages may not be available on this release"
    info "System packages installed."
    detail "gpiod       -> NRESET / SOP / HOST_INTR control"
    detail "libftdi1    -> optional USB-SPI bring-up adapters"
    detail "v4l-utils   -> CSI-2 capture debugging"
}
install_packages

# ─── 2. Host SPI master ──────────────────────────────────────────────
setup_spi() {
    section "2/7 -- Host SPI master (radar control link)"
    if [ "$PLATFORM" != "linux" ]; then
        detail "Skipped on $PLATFORM."
        return 0
    fi

    if ! lsmod 2>/dev/null | grep -q "^spidev"; then
        info "Loading spidev..."
        sudo modprobe spidev 2>/dev/null || warn "Could not load spidev (may be built in)"
    fi
    if [ ! -f /etc/modules-load.d/awr6243-spidev.conf ]; then
        info "Adding spidev to boot modules..."
        echo "spidev" | sudo tee /etc/modules-load.d/awr6243-spidev.conf > /dev/null
    fi

    if ls /dev/spidev* &>/dev/null; then
        info "SPI master nodes:"
        local node
        for node in /dev/spidev*; do
            detail "$node"
        done
    else
        warn "No /dev/spidev* nodes yet."
        if [ "$IS_JETSON" = true ]; then
            detail "On Jetson the 40-pin header pins are muxed to SPI with jetson-io:"
            detail "  sudo /opt/nvidia/jetson-io/jetson-io.py"
            detail "  -> Configure 40-pin expansion header -> enable spi1 (and spi3 if needed)"
            detail "  -> Save pin changes, save and reboot"
        else
            detail "Enable an SPI controller for your SoC in the device tree, then reboot."
        fi
    fi

    detail "mmWaveLink drives the radar with 16-bit SPI words"
    detail "(board.env: AWR6243_SPI_BITS_PER_WORD=$SPI_BITS, speed ${SPI_SPEED} Hz)"
}
setup_spi

# ─── 3. udev rules + groups ──────────────────────────────────────────
setup_access() {
    section "3/7 -- Device access (udev rules + groups)"
    if [ "$PLATFORM" != "linux" ]; then
        detail "Skipped on $PLATFORM."
        return 0
    fi

    local grp
    for grp in spi gpio i2c plugdev; do
        if ! getent group "$grp" >/dev/null 2>&1; then
            info "Creating group $grp..."
            sudo groupadd -f "$grp"
        fi
        if ! id -nG "$USER" | grep -qw "$grp"; then
            info "Adding $USER to $grp..."
            sudo usermod -aG "$grp" "$USER"
        fi
    done

    if [ -f "$UDEV_RULES" ]; then
        sudo cp "$UDEV_RULES" /etc/udev/rules.d/99-awr6243.rules
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        info "udev rules installed: /etc/udev/rules.d/99-awr6243.rules"
        detail "/dev/spidev*    group spi   -> radar control + firmware download"
        detail "/dev/gpiochip*  group gpio  -> NRESET / SOP / HOST_INTR / NERROR"
        detail "/dev/i2c-*      group i2c   -> optional I2C control path"
        detail "FTDI 0403:60xx  group plugdev -> USB-SPI bring-up adapters"
    else
        warn "udev rules file not found at $UDEV_RULES"
    fi
    warn "Log out and back in for the new group memberships to take effect."
}
setup_access

# ─── 4. Device firmware (DFP) ────────────────────────────────────────
stage_firmware() {
    section "4/7 -- Device firmware ($DFP_NAME)"
    detail "The xWR6243 has no production flash path: the datasheet marks QSPI as"
    detail "development-only, so the host downloads the firmware over SPI after"
    detail "every reset. Keep the DFP images on the host filesystem."

    mkdir -p "$DFP_ROOT"

    if [ -n "$DFP_SOURCE" ]; then
        if [ -d "$DFP_SOURCE" ]; then
            info "Copying DFP from $DFP_SOURCE ..."
            cp -r "$DFP_SOURCE"/. "$DFP_ROOT"/
        elif [ -f "$DFP_SOURCE" ]; then
            case "$DFP_SOURCE" in
                *.zip)
                    info "Extracting $(basename "$DFP_SOURCE") into $DFP_ROOT ..."
                    if command -v unzip &>/dev/null; then
                        # unzip exits 1 for non-fatal warnings (e.g. backslash paths),
                        # which set -e would otherwise turn into a silent abort.
                        local rc=0
                        unzip -q -o "$DFP_SOURCE" -d "$DFP_ROOT" || rc=$?
                        if [ "$rc" -gt 1 ]; then
                            error "unzip failed (exit $rc)"
                        elif [ "$rc" -eq 1 ]; then
                            warn "unzip finished with warnings (exit 1) — check the staged tree"
                        fi
                    else
                        error "unzip not available; extract the DFP manually into $DFP_ROOT"
                    fi
                    ;;
                *.exe)
                    warn "$(basename "$DFP_SOURCE") is the Windows installer."
                    detail "Download the .zip instead, or run the installer on Windows and"
                    detail "copy the installed tree here with --dfp <dir>."
                    ;;
                *)
                    error "Unrecognised DFP source: $DFP_SOURCE (want a .zip or a directory)"
                    ;;
            esac
        else
            error "DFP source not found: $DFP_SOURCE"
        fi
    fi

    local images
    images="$(find_fw_images)"
    if [ -n "$images" ]; then
        info "Device firmware images under $DFP_ROOT:"
        local img first=""
        for img in $images; do
            detail "$img"
            if [ -z "$first" ]; then
                first="$img"
            fi
        done
        detail "Point AWR6243_FW_IMAGE in board.env at the image your DFP release"
        detail "documents for this device, e.g. $first"
    else
        warn "No firmware images staged yet."
        print_dfp_instructions
    fi

    local api_docs
    api_docs="$(find "$DFP_ROOT" -maxdepth 4 -type d -iname "*doc*" 2>/dev/null | head -3 || true)"
    if [ -n "$api_docs" ]; then
        detail "DFP docs (mmWaveLink API guide + mmWave Radar ICD):"
        local doc
        for doc in $api_docs; do
            detail "$doc"
        done
    fi
}
stage_firmware

# ─── 5. Board config ─────────────────────────────────────────────────
setup_board_env() {
    section "5/7 -- Carrier board config"
    if [ ! -f "$BOARD_ENV" ]; then
        cp "$AWR6243_DIR/board.env.example" "$BOARD_ENV"
        info "Created $BOARD_ENV from the example."
    else
        info "Board config already exists: $BOARD_ENV"
    fi
    detail "Fill in the host SPI bus and the GPIO offsets for NRESET, SOP0-2,"
    detail "SPI_HOST_INTR_1 and NERROR_OUT. There is no standard pinout for this"
    detail "part — read them off your carrier's schematic."
    if command -v gpioinfo &>/dev/null; then
        detail "List the host's GPIO lines with:  gpiodetect ; gpioinfo"
    fi
    detail "Then drive the boot mode with:"
    detail "  bash mmwave/awr6243/radar-ctl.sh status"
    detail "  bash mmwave/awr6243/radar-ctl.sh boot spi"
}
setup_board_env

# ─── 6. Python tooling ───────────────────────────────────────────────
setup_python() {
    section "6/7 -- Python tooling"
    info "Setting up Python venv at: $RADAR_VENV"
    mkdir -p "$(dirname "$RADAR_VENV")"

    if [ ! -d "$RADAR_VENV" ]; then
        "$PYTHON_BIN" -m venv "$RADAR_VENV"
        info "Created new venv."
    else
        info "Venv already exists."
    fi

    # pip cannot replace its own launcher on Windows, so never fail on this.
    "$VENV_PYTHON" -m pip install --upgrade pip -q || warn "Could not upgrade pip in the venv"

    local pkgs=(numpy scipy websockets)
    if [ "$PLATFORM" = "linux" ]; then
        pkgs+=(spidev pyftdi)
    fi

    local reqs=""
    local loc
    for loc in "${HOME}/work/cubeship-mmwave-firmware/radar/requirements.txt" \
               "${USERPROFILE:-$HOME}/work/cubeship-mmwave-firmware/radar/requirements.txt"; do
        if [ -f "$loc" ]; then
            reqs="$loc"
            break
        fi
    done

    if [ -n "$reqs" ]; then
        info "Installing from $reqs ..."
        "$VENV_PYTHON" -m pip install -r "$reqs" -q || warn "Some requirements failed to install"
    fi
    info "Installing host-side radar packages: ${pkgs[*]}"
    "$VENV_PYTHON" -m pip install "${pkgs[@]}" -q || warn "Some packages failed to install"

    check_python
}
setup_python

# ─── 7. Raw ADC capture path ─────────────────────────────────────────
setup_capture() {
    section "7/7 -- Raw ADC capture path ($CAPTURE)"
    case "$CAPTURE" in
        csi2)
            detail "Production path: MIPI D-PHY CSI-2 v1.1, 4 data + 1 clock lane,"
            detail "150-600 Mbps per lane, ADC samples only (no detections)."
            if [ "$PLATFORM" = "linux" ]; then
                if ls /dev/video* &>/dev/null; then
                    info "V4L2 nodes present:"
                    local vid
                    for vid in /dev/video*; do
                        detail "$vid"
                    done
                    if command -v v4l2-ctl &>/dev/null; then
                        v4l2-ctl --list-devices 2>/dev/null | head -20 || true
                    fi
                else
                    warn "No /dev/video* nodes."
                    detail "The radar is not a camera: Tegra needs a device-tree overlay"
                    detail "describing it as a 4-lane CSI-2 source plus a V4L2 subdev"
                    detail "driver. TI ships no Jetson driver for this part — see"
                    detail "mmwave/README.md -> 'Capturing raw ADC data'."
                fi
            fi
            ;;
        dca1000)
            detail "Bench path: the LVDS debug port into a DCA1000EVM."
            detail "The datasheet marks LVDS as a debug interface, not for production."
            detail "Default DCA1000 networking: FPGA 192.168.33.180, host 192.168.33.30,"
            detail "config UDP 4096, record UDP 4098 (confirm in the DCA1000 user guide)."
            if [ "$PLATFORM" = "linux" ] && command -v ip &>/dev/null; then
                detail "Give the capture NIC the host address, e.g.:"
                detail "  sudo ip addr add 192.168.33.30/24 dev <iface>"
            fi
            ;;
        *)
            warn "Unknown capture path: $CAPTURE (want csi2 or dca1000)"
            ;;
    esac
}
setup_capture

# ─── Optional SPI loopback self-test ─────────────────────────────────
run_selftest() {
    section "SPI loopback self-test"
    if [ "$PLATFORM" != "linux" ]; then
        warn "Self-test needs a Linux host with spidev."
        return 0
    fi
    if [ ! -e "$SPIDEV" ]; then
        warn "$SPIDEV not present — nothing to test."
        return 0
    fi
    warn "DISCONNECT THE RADAR FIRST and jumper MOSI to MISO on the host header."
    detail "This checks the host's SPI path only; it does not talk to the device."
    if [ ! -f "$VENV_PYTHON" ]; then
        warn "Python venv not ready; run the setup without --check first."
        return 0
    fi
    AWR6243_SPIDEV="$SPIDEV" AWR6243_SPI_SPEED_HZ="$SPI_SPEED" \
    "$VENV_PYTHON" - <<'PY' || warn "SPI loopback test failed"
import os
import sys

try:
    import spidev
except ImportError:
    sys.exit("spidev not installed in the venv")

dev = os.environ.get("AWR6243_SPIDEV", "/dev/spidev0.0")
speed = int(os.environ.get("AWR6243_SPI_SPEED_HZ", "5000000"))
bus, cs = (int(x) for x in dev.rsplit("spidev", 1)[1].split("."))

spi = spidev.SpiDev()
spi.open(bus, cs)
spi.max_speed_hz = speed
spi.mode = 0

tx = [0xAA, 0x55, 0xA5, 0x5A]
rx = spi.xfer2(list(tx))
spi.close()

print(f"    -> {dev} @ {speed} Hz  tx={tx} rx={rx}")
if rx == tx:
    print("    -> loopback OK: the host SPI master works")
else:
    print("    !! mismatch: no jumper, wrong pinmux, or the bus is not driven")
    sys.exit(1)
PY
}
if [ "$RUN_SELFTEST" = true ]; then
    run_selftest
fi

# ═══════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "================================================================="
echo "  AWR6243 host setup complete  ($PLATFORM)"
echo "================================================================="
echo ""
echo "  Control link:   $SPIDEV  (radar is the SPI peripheral, ${SPI_BITS}-bit words)"
echo "  Boot mode:      SOP2 SOP1 SOP0 = 0 0 1 for functional SPI"
echo "  Firmware:       $DFP_ROOT  ($DFP_NAME $DFP_VERSION)"
echo "  Board config:   $BOARD_ENV"
echo "  Capture path:   $CAPTURE"
echo "  Python venv:    $RADAR_VENV"
echo ""
echo "  Next steps:"
echo "  1. Log out and back in (spi/gpio/i2c/plugdev groups)"
echo "  2. Fill in the GPIO offsets and SPI bus in board.env"
echo "  3. Stage the DFP:  bash mmwave/setup-awr6243.sh --dfp <mmwave_dfp_*.zip>"
echo "  4. Strap and reset:  bash mmwave/awr6243/radar-ctl.sh boot spi"
echo "  5. From your host app (source $VENV_ACTIVATE):"
echo "     power on, download the firmware over SPI, wait for"
echo "     the power-up async event, then run the mmWaveLink config sequence"
echo "     (channel/ADC -> RF init -> CSI-2 data path -> profile/chirp/frame -> start)"
echo "  6. Verify:  bash mmwave/setup-awr6243.sh --check"
echo ""
echo "  Datasheet: https://www.ti.com/lit/ds/symlink/iwr6243.pdf  (SWRS283A)"
echo "  Details:   mmwave/README.md"
echo "================================================================="
