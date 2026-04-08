#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  OpenCV installer for NVIDIA Jetson Orin Nano                       ║
# ║  Ubuntu 22.04 · JetPack 6.x · aarch64 · CUDA 12.x                 ║
# ║                                                                      ║
# ║  Builds OpenCV with CUDA, cuDNN, GStreamer, and V4L2 support from   ║
# ║  source. The stock apt OpenCV (4.5.4) has NO CUDA support.          ║
# ║                                                                      ║
# ║  Based on: https://github.com/AastaNV/JEP                          ║
# ║                                                                      ║
# ║  Usage:                                                              ║
# ║    bash opencv/setup-opencv-jetson.sh                                ║
# ║    bash opencv/setup-opencv-jetson.sh --remove-old                  ║
# ║    bash opencv/setup-opencv-jetson.sh --cleanup                     ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────
# Update this version when new OpenCV releases come out.
# Check: https://github.com/opencv/opencv/releases

OPENCV_VERSION="4.13.0"

# Orin Nano (Ampere) CUDA compute capability
CUDA_ARCH_BIN="8.7"

# Build directory (removed after install unless --keep-build is passed)
BUILD_DIR="/tmp/opencv-build"

# Parallel jobs — Jetson Orin Nano has 8 GB RAM; each compiler job uses
# ~1.5 GB during CUDA compilation. Default to 4 to avoid OOM kills.
# Override: MAKE_JOBS=6 bash opencv/setup-opencv-jetson.sh
MAKE_JOBS="${MAKE_JOBS:-4}"

# ─── Colors ────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*" >&2; }
section() { echo -e "\n${BLUE}━━━ $* ━━━${NC}"; }

# ─── Pre-flight checks ────────────────────────────────────────────
check_jetson() {
    if [ ! -f /etc/nv_tegra_release ] && [ ! -d /usr/src/jetson_multimedia_api ]; then
        error "This does not appear to be a Jetson device."
        error "This script is designed for NVIDIA Jetson platforms only."
        exit 1
    fi
    info "Jetson platform detected."
}

check_cuda() {
    if ! command -v nvcc &>/dev/null; then
        error "CUDA toolkit not found. Install JetPack or CUDA Toolkit first."
        error "  sudo apt install nvidia-jetpack"
        exit 1
    fi
    local cuda_ver
    cuda_ver=$(nvcc --version | grep -oP 'release \K[0-9]+\.[0-9]+')
    info "CUDA version: $cuda_ver"
}

check_disk_space() {
    # OpenCV build needs ~8 GB of free space
    local avail_gb
    avail_gb=$(df --output=avail /tmp | tail -1 | awk '{printf "%.0f", $1/1048576}')
    if [ "$avail_gb" -lt 8 ]; then
        warn "Only ${avail_gb} GB free in /tmp. OpenCV build needs ~8 GB."
        warn "Consider setting BUILD_DIR to a path with more space."
    else
        info "Disk space: ${avail_gb} GB available in /tmp — OK"
    fi
}

check_memory() {
    local total_mb
    total_mb=$(free -m | awk '/Mem:/ {print $2}')
    info "Total RAM: ${total_mb} MB (using $MAKE_JOBS parallel jobs)"
    if [ "$total_mb" -lt 6000 ] && [ "$MAKE_JOBS" -gt 2 ]; then
        warn "Low RAM detected. Consider: MAKE_JOBS=2 bash opencv/setup-opencv-jetson.sh"
    fi
}

# ─── Remove old OpenCV ────────────────────────────────────────────
remove_old_opencv() {
    section "Removing Existing OpenCV"
    sudo apt-get -y purge '*libopencv*' 2>/dev/null || true
    sudo apt-get -y autoremove 2>/dev/null || true
    info "Old OpenCV packages removed."
}

# ─── Install build dependencies ───────────────────────────────────
install_dependencies() {
    section "Installing Build Dependencies (1/4)"

    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        build-essential cmake git unzip curl pkg-config \
        libgtk2.0-dev \
        libavcodec-dev libavformat-dev libswscale-dev \
        libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
        python3.10-dev python3-numpy \
        libtbb2 libtbb-dev \
        libjpeg-dev libpng-dev libtiff-dev \
        libv4l-dev v4l-utils qv4l2 \
        libdc1394-dev libxvidcore-dev libx264-dev \
        libatlas-base-dev gfortran

    info "Build dependencies installed."
}

# ─── Download OpenCV source ───────────────────────────────────────
download_opencv() {
    section "Downloading OpenCV ${OPENCV_VERSION} (2/4)"

    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    info "Downloading opencv..."
    curl -L "https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip" -o "opencv-${OPENCV_VERSION}.zip"
    info "Downloading opencv_contrib..."
    curl -L "https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip" -o "opencv_contrib-${OPENCV_VERSION}.zip"

    unzip -q "opencv-${OPENCV_VERSION}.zip"
    unzip -q "opencv_contrib-${OPENCV_VERSION}.zip"
    rm -f "opencv-${OPENCV_VERSION}.zip" "opencv_contrib-${OPENCV_VERSION}.zip"

    info "Source downloaded and extracted."
}

# ─── Build OpenCV ─────────────────────────────────────────────────
build_opencv() {
    section "Building OpenCV ${OPENCV_VERSION} with CUDA (3/4)"

    cd "$BUILD_DIR/opencv-${OPENCV_VERSION}"
    mkdir -p release
    cd release

    info "Running cmake..."
    cmake \
        -D CMAKE_BUILD_TYPE=RELEASE \
        -D CMAKE_INSTALL_PREFIX=/usr/local \
        -D WITH_CUDA=ON \
        -D WITH_CUDNN=ON \
        -D CUDA_ARCH_BIN="$CUDA_ARCH_BIN" \
        -D CUDA_ARCH_PTX="" \
        -D OPENCV_GENERATE_PKGCONFIG=ON \
        -D OPENCV_EXTRA_MODULES_PATH="../../opencv_contrib-${OPENCV_VERSION}/modules" \
        -D WITH_GSTREAMER=ON \
        -D WITH_LIBV4L=ON \
        -D WITH_TBB=ON \
        -D BUILD_opencv_python3=ON \
        -D BUILD_TESTS=OFF \
        -D BUILD_PERF_TESTS=OFF \
        -D BUILD_EXAMPLES=OFF \
        -D OPENCV_DNN_CUDA=ON \
        ..

    info "Compiling with $MAKE_JOBS parallel jobs (this will take a while)..."
    make -j"$MAKE_JOBS"

    info "Build complete."
}

# ─── Install OpenCV ───────────────────────────────────────────────
install_opencv() {
    section "Installing OpenCV ${OPENCV_VERSION} (4/4)"

    cd "$BUILD_DIR/opencv-${OPENCV_VERSION}/release"
    sudo make install
    sudo ldconfig

    info "OpenCV installed to /usr/local."
}

# ─── Environment setup ────────────────────────────────────────────
setup_env() {
    section "Environment Variables"

    local shell_rc=""
    if [ -f "$HOME/.zshrc" ]; then
        shell_rc="$HOME/.zshenv"
    else
        shell_rc="$HOME/.bashrc"
    fi

    local exports=(
        'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH'
        'export PYTHONPATH=/usr/local/lib/python3.10/site-packages/:$PYTHONPATH'
    )

    for line in "${exports[@]}"; do
        if ! grep -qF "$line" "$shell_rc" 2>/dev/null; then
            echo "$line" >> "$shell_rc"
            info "Added to $shell_rc: $line"
        else
            info "Already in $shell_rc: $line"
        fi
    done
}

# ─── Cleanup ──────────────────────────────────────────────────────
cleanup() {
    section "Cleanup"
    rm -rf "$BUILD_DIR"
    info "Build directory removed: $BUILD_DIR"
}

# ─── Verification ─────────────────────────────────────────────────
verify_install() {
    section "Verification"

    # Reload library cache
    export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH:-}
    export PYTHONPATH=/usr/local/lib/python3.10/site-packages/:${PYTHONPATH:-}

    python3 -c "
import cv2
print(f'  OpenCV version: {cv2.__version__}')
build_info = cv2.getBuildInformation()
cuda_status = 'CUDA' in build_info and 'YES' in build_info.split('CUDA')[1][:50]
print(f'  CUDA support:   {\"YES\" if cuda_status else \"NO\"} ')
devices = cv2.cuda.getCudaEnabledDeviceCount()
print(f'  CUDA devices:   {devices}')
" || {
        warn "Python verification failed. Try: python3 -c 'import cv2; print(cv2.__version__)'"
    }

    # Also check pkg-config
    if command -v pkg-config &>/dev/null; then
        local pc_ver
        pc_ver=$(pkg-config --modversion opencv4 2>/dev/null || echo "not found")
        info "pkg-config opencv4: $pc_ver"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --remove-old    Remove existing apt OpenCV packages before building"
    echo "  --cleanup       Only remove the build directory (post-install)"
    echo "  --keep-build    Don't remove the build directory after install"
    echo "  --help, -h      Show this help"
    echo ""
    echo "Environment:"
    echo "  MAKE_JOBS=N     Number of parallel compile jobs (default: 4)"
    echo "  BUILD_DIR=PATH  Build directory (default: /tmp/opencv-build)"
}

main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  OpenCV ${OPENCV_VERSION} Installer for Jetson Orin Nano          ║"
    echo "║  CUDA + cuDNN + GStreamer + V4L2 + contrib modules          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    local remove_old=false
    local keep_build=false

    for arg in "$@"; do
        case "$arg" in
            --remove-old)  remove_old=true ;;
            --keep-build)  keep_build=true ;;
            --cleanup)     cleanup; exit 0 ;;
            --help|-h)     usage; exit 0 ;;
            *)             error "Unknown option: $arg"; usage; exit 1 ;;
        esac
    done

    check_jetson
    check_cuda
    check_disk_space
    check_memory

    if [ "$remove_old" = true ]; then
        remove_old_opencv
    fi

    local start_time
    start_time=$(date +%s)

    install_dependencies
    download_opencv
    build_opencv
    install_opencv
    setup_env

    if [ "$keep_build" = false ]; then
        cleanup
    else
        info "Build directory kept at: $BUILD_DIR"
    fi

    verify_install

    local end_time elapsed_min
    end_time=$(date +%s)
    elapsed_min=$(( (end_time - start_time) / 60 ))

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✓ OpenCV ${OPENCV_VERSION} installed successfully!               ║"
    echo "║                                                              ║"
    echo "║  Build time: ~${elapsed_min} minutes                                  ║"
    echo "║                                                              ║"
    echo "║  Verify:                                                     ║"
    echo "║    python3 -c 'import cv2; print(cv2.__version__)'           ║"
    echo "║    python3 -c 'import cv2; print(cv2.cuda.getCudaEnabledDeviceCount())'  ║"
    echo "║                                                              ║"
    echo "║  If using a venv, reinstall numpy and re-link:              ║"
    echo "║    pip install numpy opencv-python-headless                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
}

main "$@"
