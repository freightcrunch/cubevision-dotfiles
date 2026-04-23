#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  mmWave Radar Driver Setup — RS-2944A                               ║
# ║                                                                      ║
# ║  Cross-platform: native Linux (Jetson) · WSL2 · Windows (Git Bash)  ║
# ║                                                                      ║
# ║  Installs CP2105 USB-to-UART driver, udev rules / COM port config,  ║
# ║  Python radar dependencies, and optionally ROS Melodic (Docker).    ║
# ║                                                                      ║
# ║  Usage:                                                              ║
# ║    bash mmwave/setup-mmwave.sh                                       ║
# ║    bash mmwave/setup-mmwave.sh --check                              ║
# ║    bash mmwave/setup-mmwave.sh --ros                                ║
# ║    bash mmwave/setup-mmwave.sh --venv /path/to/venv                 ║
# ║    bash mmwave/setup-mmwave.sh --skip-reboot                        ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
MMWAVE_DIR="$DOTFILES/mmwave"

# ─── Defaults ────────────────────────────────────────────────────────
INSTALL_ROS=false
CHECK_ONLY=false
SKIP_REBOOT=false
ROS_WS="${HOME}/catkin_ws"
ROS_DOCKER_IMAGE="cubeship/ros-melodic-mmwave"

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

# Platform-specific venv defaults
case "$PLATFORM" in
    windows)
        RADAR_VENV="${USERPROFILE:-$HOME}/.venvs/radar"
        PYTHON_BIN="python"
        PIP_BIN="$RADAR_VENV/Scripts/pip.exe"
        VENV_PYTHON="$RADAR_VENV/Scripts/python.exe"
        VENV_ACTIVATE="$RADAR_VENV/Scripts/activate"
        ;;
    *)
        RADAR_VENV="${HOME}/.venvs/radar"
        PYTHON_BIN="python3"
        PIP_BIN="$RADAR_VENV/bin/pip"
        VENV_PYTHON="$RADAR_VENV/bin/python"
        VENV_ACTIVATE="$RADAR_VENV/bin/activate"
        ;;
esac

# ─── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[x]${NC} $*" >&2; }
section() { echo -e "\n${BLUE}--- $* ---${NC}"; }
detail()  { echo -e "    ${CYAN}->${NC} $*"; }

# ─── Parse arguments ────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)       CHECK_ONLY=true ;;
        --ros)         INSTALL_ROS=true ;;
        --venv)        shift; RADAR_VENV="$1" ;;
        --skip-reboot) SKIP_REBOOT=true ;;
        --help|-h)
            echo "Usage: $0 [--check] [--ros] [--venv /path] [--skip-reboot]"
            echo ""
            echo "  --check        Check current driver state only (no changes)"
            echo "  --ros          Install ROS Melodic desktop-full + ti_mmwave_rospkg (Docker)"
            echo "  --venv PATH    Python venv path (default: ~/.venvs/radar)"
            echo "  --skip-reboot  Skip reboot prompt at end"
            echo ""
            echo "  Detected platform: $PLATFORM"
            exit 0
            ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# ═══════════════════════════════════════════════════════════════════════
# CHECK MODE
# ═══════════════════════════════════════════════════════════════════════

check_status_linux() {
    section "mmWave Radar -- Current State (Linux)"

    # Kernel module
    if lsmod | grep -q cp210x 2>/dev/null; then
        info "cp210x kernel module: LOADED"
    elif modinfo cp210x &>/dev/null; then
        warn "cp210x kernel module: AVAILABLE but not loaded"
    else
        error "cp210x kernel module: NOT FOUND in kernel"
    fi

    # udev rules
    if [ -f /etc/udev/rules.d/99-mmwave-radar.rules ]; then
        info "udev rules: INSTALLED"
    else
        warn "udev rules: NOT INSTALLED"
    fi

    # dialout group
    if id -nG "$USER" | grep -qw dialout; then
        info "dialout group: $USER is a member"
    else
        warn "dialout group: $USER is NOT a member"
    fi

    # USB devices
    echo ""
    if lsusb 2>/dev/null | grep -qi "10c4.*ea70\|silicon.*cp2105"; then
        info "CP2105 USB device: DETECTED"
        lsusb | grep -i "10c4\|silicon" | while read -r line; do
            detail "$line"
        done
    else
        warn "CP2105 USB device: not currently connected"
    fi

    # Device nodes
    echo ""
    local found_dev=false
    for dev in /dev/radar_cfg /dev/radar_data /dev/mmWave_*; do
        if [ -e "$dev" ]; then
            found_dev=true
            local target
            target=$(readlink -f "$dev" 2>/dev/null || echo "?")
            info "Device: $dev -> $target"
        fi
    done
    if [ "$found_dev" = false ]; then
        warn "No radar device symlinks found (is the sensor connected?)"
    fi

    for dev in /dev/ttyUSB*; do
        [ -e "$dev" ] && detail "Serial port: $dev"
    done
}

check_status_wsl2() {
    section "mmWave Radar -- Current State (WSL2)"

    # usbipd availability (Windows side)
    if command -v usbipd.exe &>/dev/null || command -v usbipd &>/dev/null; then
        info "usbipd-win: AVAILABLE"
        # list attached USB devices
        usbipd.exe list 2>/dev/null | grep -i "silicon\|cp210\|10c4" | while read -r line; do
            detail "$line"
        done || warn "No CP2105 found in usbipd device list"
    else
        warn "usbipd-win: NOT INSTALLED"
        detail "Install on Windows: winget install usbipd"
    fi

    # Check if device made it through
    for dev in /dev/ttyUSB*; do
        [ -e "$dev" ] && info "Serial port (attached via usbipd): $dev"
    done

    # Kernel module (WSL2 has cp210x built-in on recent kernels)
    if lsmod 2>/dev/null | grep -q cp210x; then
        info "cp210x kernel module: LOADED"
    elif modinfo cp210x &>/dev/null 2>&1; then
        warn "cp210x kernel module: available but not loaded"
    else
        warn "cp210x kernel module: may be built-in or unavailable"
    fi
}

check_status_windows() {
    section "mmWave Radar -- Current State (Windows)"

    # Check for CP2105 driver via Windows Device Manager
    if command -v powershell.exe &>/dev/null; then
        local com_ports
        com_ports=$(powershell.exe -NoProfile -Command \
            "Get-WmiObject Win32_PnPEntity | Where-Object { \$_.Name -match 'CP210' -or \$_.Name -match 'Silicon Labs' } | Select-Object -ExpandProperty Name" 2>/dev/null || true)
        if [ -n "$com_ports" ]; then
            info "CP2105 device detected:"
            echo "$com_ports" | while read -r line; do
                detail "$line"
            done
        else
            warn "CP2105 not found in Device Manager"
            detail "Connect the RS-2944A and install the CP210x driver"
            detail "  https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers"
        fi
    fi

    # Check Python
    if command -v python &>/dev/null; then
        info "Python: $(python --version 2>&1)"
    else
        warn "Python: NOT FOUND"
    fi
}

check_status_common() {
    echo ""
    # Python venv
    if [ -d "$RADAR_VENV" ] && [ -f "$VENV_PYTHON" ]; then
        info "Python venv: $RADAR_VENV"
        "$VENV_PYTHON" -c "import serial; print(f'  pyserial {serial.VERSION}')" 2>/dev/null || \
            warn "pyserial not installed in venv"
    else
        warn "Python venv: not found at $RADAR_VENV"
    fi

    # ROS Melodic (Docker) — Linux/WSL2 only
    if [ "$PLATFORM" != "windows" ]; then
        if docker image inspect "$ROS_DOCKER_IMAGE" &>/dev/null 2>&1; then
            info "ROS Melodic Docker image: $ROS_DOCKER_IMAGE (built)"
        elif command -v docker &>/dev/null; then
            detail "ROS Melodic Docker image: not built (use --ros to build)"
        else
            detail "Docker: not installed (required for ROS Melodic)"
        fi
    fi
}

if [ "$CHECK_ONLY" = true ]; then
    case "$PLATFORM" in
        linux) check_status_linux ;;
        wsl2)  check_status_wsl2 ;;
        windows) check_status_windows ;;
    esac
    check_status_common
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════
# MAIN INSTALL
# ═══════════════════════════════════════════════════════════════════════

echo "================================================================="
echo "  mmWave Radar Setup -- RS-2944A"
echo "  Platform: $PLATFORM"
echo "  CP2105 USB-UART / Python radar stack"
echo "================================================================="
echo ""

# ─── 1. System packages / driver ─────────────────────────────────────

install_system_linux() {
    section "1/6 -- System Packages (Linux)"
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        python3-serial python3-pip python3-venv \
        linux-tools-common usbutils minicom screen \
        || warn "Some packages may not be available"
    info "System packages installed."
}

install_system_wsl2() {
    section "1/6 -- System Packages (WSL2)"
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        python3-serial python3-pip python3-venv \
        usbutils minicom screen \
        || warn "Some packages may not be available"
    info "System packages installed."

    # Check usbipd-win on the Windows side
    if ! command -v usbipd.exe &>/dev/null && ! command -v usbipd &>/dev/null; then
        warn "usbipd-win not found on Windows host."
        detail "Install it: winget install usbipd"
        detail "Then attach the CP2105: usbipd bind --busid <BUSID>"
        detail "                         usbipd attach --wsl --busid <BUSID>"
    else
        info "usbipd-win found on Windows host."
        detail "To attach CP2105 to WSL2:"
        detail "  (PowerShell Admin) usbipd list"
        detail "  (PowerShell Admin) usbipd bind --busid <BUSID>"
        detail "  (PowerShell Admin) usbipd attach --wsl --busid <BUSID>"
    fi
}

install_system_windows() {
    section "1/6 -- CP2105 Driver (Windows)"

    # Check if driver is already installed
    local driver_found=false
    if command -v powershell.exe &>/dev/null; then
        local result
        result=$(powershell.exe -NoProfile -Command \
            "Get-WmiObject Win32_PnPEntity | Where-Object { \$_.Name -match 'CP210' } | Measure-Object | Select-Object -ExpandProperty Count" 2>/dev/null || echo "0")
        if [ "${result//[^0-9]/}" -gt 0 ] 2>/dev/null; then
            driver_found=true
        fi
    fi

    if [ "$driver_found" = true ]; then
        info "CP2105 driver already installed."
    else
        warn "CP2105 driver not detected."
        detail "Download and install from Silicon Labs:"
        detail "  https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers"
        detail ""
        detail "After installing, the sensor will appear as two COM ports in Device Manager:"
        detail "  - Silicon Labs CP210x USB to UART Bridge (COM#) -- config port (115200)"
        detail "  - Silicon Labs CP210x USB to UART Bridge (COM#) -- data port (921600)"
    fi

    # Verify Python is available
    if ! command -v python &>/dev/null; then
        warn "Python not found. Install via: scoop install python"
    else
        info "Python available: $(python --version 2>&1)"
    fi
}

case "$PLATFORM" in
    linux)   install_system_linux ;;
    wsl2)    install_system_wsl2 ;;
    windows) install_system_windows ;;
esac

# ─── 2. CP2105 kernel module (Linux / WSL2 only) ─────────────────────

install_kernel_module() {
    section "2/6 -- CP2105 Kernel Module (cp210x)"

    if modinfo cp210x &>/dev/null; then
        info "cp210x module found in kernel."
    else
        warn "cp210x module not found. Attempting to load..."
        error "cp210x not available. You may need to enable CONFIG_USB_SERIAL_CP210X"
        error "in your kernel config and rebuild. See:"
        error "  https://forums.developer.nvidia.com/t/enable-config-usb-serial-pl2303-on-kernel/285574"
        if [ "$PLATFORM" = "linux" ]; then
            error "For JetPack 6.x this should already be included. Check with:"
            error "  zcat /proc/config.gz | grep CP210X"
        fi
    fi

    # Load the module now
    if ! lsmod | grep -q cp210x; then
        info "Loading cp210x module..."
        sudo modprobe cp210x || warn "Could not load cp210x (may already be built-in)"
    fi

    # Ensure it loads on boot (native Linux only, WSL2 kernel is managed by Windows)
    if [ "$PLATFORM" = "linux" ]; then
        if [ ! -f /etc/modules-load.d/mmwave-cp210x.conf ]; then
            info "Adding cp210x to boot modules..."
            echo "cp210x" | sudo tee /etc/modules-load.d/mmwave-cp210x.conf > /dev/null
        fi
    fi

    info "cp210x kernel module configured."
}

if [ "$PLATFORM" != "windows" ]; then
    install_kernel_module
else
    section "2/6 -- Kernel Module (Skipped on Windows)"
    detail "Windows uses the Silicon Labs VCP driver instead of a kernel module."
fi

# ─── 3. udev rules (Linux / WSL2 only) ──────────────────────────────

install_udev_rules() {
    section "3/6 -- udev Rules (stable /dev/radar_* symlinks)"

    if [ -f "$MMWAVE_DIR/99-mmwave-radar.rules" ]; then
        sudo cp "$MMWAVE_DIR/99-mmwave-radar.rules" /etc/udev/rules.d/99-mmwave-radar.rules
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        info "udev rules installed:"
        detail "/dev/mmWave_<serial>_00  ->  config port (115200 baud)"
        detail "/dev/mmWave_<serial>_01  ->  data port (921600 baud)"
        detail "/dev/radar_cfg           ->  config port alias"
        detail "/dev/radar_data          ->  data port alias"
    else
        warn "udev rules file not found at $MMWAVE_DIR/99-mmwave-radar.rules"
    fi
}

if [ "$PLATFORM" = "linux" ]; then
    install_udev_rules
elif [ "$PLATFORM" = "wsl2" ]; then
    install_udev_rules
else
    section "3/6 -- Serial Port Configuration (Windows)"
    detail "Windows assigns COM ports automatically via Device Manager."
    detail "To find your ports, run in PowerShell:"
    detail "  Get-WmiObject Win32_SerialPort | Select-Object DeviceID, Description"
    detail ""
    detail "Or check Device Manager -> Ports (COM & LPT)"
    detail "  Config port (115200 baud) = lower COM number"
    detail "  Data port   (921600 baud) = higher COM number"
fi

# ─── 4. User permissions ────────────────────────────────────────────

if [ "$PLATFORM" != "windows" ]; then
    section "4/6 -- User Permissions (dialout group)"
    if id -nG "$USER" | grep -qw dialout; then
        info "$USER is already in the dialout group."
    else
        info "Adding $USER to the dialout group..."
        sudo usermod -aG dialout "$USER"
        warn "You must log out and back in for group changes to take effect."
    fi
else
    section "4/6 -- User Permissions (Skipped on Windows)"
    detail "Windows does not require dialout group membership for COM port access."
fi

# ─── 5. Python virtual environment + radar dependencies ─────────────
section "5/6 -- Python Radar Dependencies"

info "Setting up Python venv at: $RADAR_VENV"
mkdir -p "$(dirname "$RADAR_VENV")"

if [ ! -d "$RADAR_VENV" ]; then
    "$PYTHON_BIN" -m venv "$RADAR_VENV"
    info "Created new venv."
else
    info "Venv already exists."
fi

"$PIP_BIN" install --upgrade pip -q

# Install radar requirements if the cubeship-mmwave-firmware repo exists
RADAR_REQS_LOCATIONS=(
    "$HOME/work/cubeship-mmwave-firmware/radar/requirements.txt"
    "${USERPROFILE:-$HOME}/work/cubeship-mmwave-firmware/radar/requirements.txt"
)
RADAR_REQS=""
for loc in "${RADAR_REQS_LOCATIONS[@]}"; do
    if [ -f "$loc" ]; then
        RADAR_REQS="$loc"
        break
    fi
done

if [ -n "$RADAR_REQS" ]; then
    info "Installing from $RADAR_REQS..."
    "$PIP_BIN" install -r "$RADAR_REQS" -q
else
    info "Installing core radar packages..."
    "$PIP_BIN" install pyserial numpy websockets scipy -q
fi

# Verify
"$VENV_PYTHON" -c "
import serial, numpy, websockets
print(f'  pyserial   {serial.VERSION}')
print(f'  numpy      {numpy.__version__}')
print(f'  websockets {websockets.__version__}')
" && info "Python radar packages verified." || warn "Some packages failed to import."

# ─── 6. (Optional) ROS Melodic — Docker (Linux / WSL2 only) ─────────
if [ "$INSTALL_ROS" = true ]; then
    if [ "$PLATFORM" = "windows" ]; then
        error "ROS Melodic Docker is not supported natively on Windows."
        error "Use WSL2 instead:  wsl bash mmwave/setup-mmwave.sh --ros"
    else
        section "6/6 -- ROS Melodic desktop-full (Docker) + ti_mmwave_rospkg"

        if ! command -v docker &>/dev/null; then
            error "Docker is required for ROS Melodic."
            error "Install Docker first:  sudo apt-get install -y docker.io"
            error "Then re-run:  bash mmwave/setup-mmwave.sh --ros"
            exit 1
        fi

        if ! id -nG "$USER" | grep -qw docker; then
            info "Adding $USER to docker group..."
            sudo usermod -aG docker "$USER"
            warn "You may need to log out and back in for docker group to take effect."
        fi

        ROS_DOCKER_DIR="$MMWAVE_DIR/ros-melodic-docker"
        mkdir -p "$ROS_DOCKER_DIR"

        info "Writing Dockerfile for ROS Melodic..."
        cat > "$ROS_DOCKER_DIR/Dockerfile" << 'DOCKERFILE'
FROM ros:melodic-ros-base-bionic

ENV DEBIAN_FRONTEND=noninteractive

# Install ros-melodic-desktop-full and build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-melodic-desktop-full \
        ros-melodic-serial \
        ros-melodic-rviz \
        python-catkin-tools \
        python-pip \
        git \
    && rm -rf /var/lib/apt/lists/*

# Create catkin workspace and clone TI mmWave ROS driver
RUN mkdir -p /catkin_ws/src
WORKDIR /catkin_ws/src
RUN git clone https://github.com/radar-lab/ti_mmwave_rospkg.git \
    && git clone https://github.com/wjwwood/serial.git

# Build the workspace
WORKDIR /catkin_ws
RUN /bin/bash -c "source /opt/ros/melodic/setup.bash && catkin_make"

# Source workspace on shell entry
RUN echo "source /opt/ros/melodic/setup.bash" >> /root/.bashrc \
    && echo "source /catkin_ws/devel/setup.bash" >> /root/.bashrc

# Default: launch an interactive shell
CMD ["/bin/bash"]
DOCKERFILE

        cat > "$ROS_DOCKER_DIR/run-ros-melodic.sh" << 'LAUNCHER'
#!/usr/bin/env bash
# Launch ROS Melodic container with USB serial device passthrough
# Usage:
#   bash run-ros-melodic.sh                         # interactive shell
#   bash run-ros-melodic.sh roslaunch ti_mmwave_rospkg 1642es2_short_range.launch
#
set -euo pipefail

IMAGE="cubeship/ros-melodic-mmwave"

# Collect all ttyUSB and mmWave devices for passthrough
DEVICE_ARGS=""
for dev in /dev/ttyUSB* /dev/radar_cfg /dev/radar_data; do
    [ -e "$dev" ] && DEVICE_ARGS+="--device=$dev "
done

# Allow GUI (rviz) via X11 forwarding
XSOCK=/tmp/.X11-unix
XAUTH=/tmp/.docker.xauth
if [ -n "${DISPLAY:-}" ]; then
    touch "$XAUTH"
    xauth nlist "$DISPLAY" | sed -e 's/^..../ffff/' | xauth -f "$XAUTH" nmerge - 2>/dev/null || true
    DISPLAY_ARGS="-e DISPLAY=$DISPLAY -v $XSOCK:$XSOCK:rw -v $XAUTH:$XAUTH:rw -e XAUTHORITY=$XAUTH"
else
    DISPLAY_ARGS=""
fi

# shellcheck disable=SC2086
docker run -it --rm \
    --net=host \
    --privileged \
    $DEVICE_ARGS \
    $DISPLAY_ARGS \
    -v "${HOME}/work/cubeship-mmwave-firmware/radar/config:/radar_config:ro" \
    "$IMAGE" \
    "${@:-/bin/bash}"
LAUNCHER
        chmod +x "$ROS_DOCKER_DIR/run-ros-melodic.sh"

        if docker image inspect "$ROS_DOCKER_IMAGE" &>/dev/null 2>&1; then
            info "Docker image $ROS_DOCKER_IMAGE already exists."
            read -rp "  Rebuild? [y/N] " rebuild
            if [[ ! "$rebuild" =~ ^[Yy]$ ]]; then
                info "Skipping rebuild."
            else
                info "Rebuilding Docker image (this may take 10-20 min)..."
                docker build -t "$ROS_DOCKER_IMAGE" "$ROS_DOCKER_DIR"
            fi
        else
            info "Building Docker image $ROS_DOCKER_IMAGE (this may take 10-20 min)..."
            docker build -t "$ROS_DOCKER_IMAGE" "$ROS_DOCKER_DIR"
        fi

        info "ROS Melodic desktop-full + ti_mmwave_rospkg ready."
        echo ""
        detail "Interactive shell:  bash $ROS_DOCKER_DIR/run-ros-melodic.sh"
        detail "Launch radar:       bash $ROS_DOCKER_DIR/run-ros-melodic.sh roslaunch ti_mmwave_rospkg 1642es2_short_range.launch"
        detail "Rviz visualizer:    bash $ROS_DOCKER_DIR/run-ros-melodic.sh roslaunch ti_mmwave_rospkg rviz_1642_2d.launch"
        detail "Custom config:      Mount /radar_config/<your>.cfg and use mmWaveQuickConfig"
    fi
else
    section "6/6 -- ROS Melodic (Skipped)"
    detail "Pass --ros to install ROS Melodic desktop-full + ti_mmwave_rospkg (Docker)."
fi

# ═══════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "================================================================="
echo "  mmWave Radar Setup Complete  ($PLATFORM)"
echo "================================================================="
echo ""

case "$PLATFORM" in
    linux)
        echo "  Kernel module:  cp210x (loaded + boot persistent)"
        echo "  udev rules:     /etc/udev/rules.d/99-mmwave-radar.rules"
        echo "  Device links:   /dev/radar_cfg  (config, 115200)"
        echo "                  /dev/radar_data (data,   921600)"
        echo "  Python venv:    $RADAR_VENV"
        echo "  dialout group:  $USER"
        echo ""
        echo "  Next steps:"
        echo "  1. Log out and back in (for dialout group)"
        echo "  2. Connect RS-2944A via USB"
        echo "  3. Verify: ls -la /dev/radar_*"
        echo "  4. Test: screen /dev/radar_cfg 115200"
        echo "  5. Run bridge:"
        echo "     source $VENV_ACTIVATE"
        echo "     python ~/work/cubeship-mmwave-firmware/radar/radar_bridge.py"
        ;;
    wsl2)
        echo "  Kernel module:  cp210x (WSL2 kernel)"
        echo "  udev rules:     /etc/udev/rules.d/99-mmwave-radar.rules"
        echo "  Device links:   /dev/radar_cfg, /dev/radar_data (after usbipd attach)"
        echo "  Python venv:    $RADAR_VENV"
        echo "  dialout group:  $USER"
        echo ""
        echo "  Next steps:"
        echo "  1. On Windows (admin PowerShell):"
        echo "       usbipd list                              # find BUSID for CP2105"
        echo "       usbipd bind --busid <BUSID>              # one-time bind"
        echo "       usbipd attach --wsl --busid <BUSID>      # attach to WSL2"
        echo "  2. In WSL2: ls -la /dev/ttyUSB*"
        echo "  3. Test: screen /dev/ttyUSB0 115200"
        echo "  4. Run bridge:"
        echo "     source $VENV_ACTIVATE"
        echo "     python ~/work/cubeship-mmwave-firmware/radar/radar_bridge.py"
        ;;
    windows)
        echo "  Driver:         Silicon Labs CP210x VCP"
        echo "  Ports:          Check Device Manager -> Ports (COM & LPT)"
        echo "  Python venv:    $RADAR_VENV"
        echo ""
        echo "  Next steps:"
        echo "  1. Install CP210x driver (if not done):"
        echo "       https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers"
        echo "  2. Connect RS-2944A via USB"
        echo "  3. Find COM ports in Device Manager"
        echo "  4. Test with PuTTY or TeraTerm: COM# at 115200 baud"
        echo "  5. Run bridge:"
        echo "     $VENV_ACTIVATE"
        echo "     python %USERPROFILE%\\work\\cubeship-mmwave-firmware\\radar\\radar_bridge.py --port COM#"
        ;;
esac

echo ""
echo "================================================================="

# ─── Reboot/logout prompt (Linux/WSL2 only) ──────────────────────────
if [ "$PLATFORM" != "windows" ] && [ "$SKIP_REBOOT" = false ]; then
    echo ""
    warn "A logout/login is needed for dialout group membership."
    read -rp "Log out now? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        info "Logging out..."
        loginctl terminate-user "$USER" 2>/dev/null || {
            warn "Could not auto-logout. Please log out manually."
        }
    fi
fi
