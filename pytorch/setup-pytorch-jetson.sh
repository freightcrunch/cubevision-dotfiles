#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  PyTorch & TorchVision installer for NVIDIA Jetson Orin Nano        ║
# ║  Ubuntu 22.04 · JetPack 6.x · aarch64 · CUDA 12.x                 ║
# ║                                                                      ║
# ║  This script installs PyTorch and TorchVision from NVIDIA's          ║
# ║  official Jetson wheels — PyPI wheels do NOT include CUDA support    ║
# ║  for aarch64.                                                        ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────
# Update these versions as NVIDIA releases new JetPack-compatible wheels.
# Check: https://forums.developer.nvidia.com/t/pytorch-for-jetson/72048
# and:   https://elinux.org/Jetson_Zoo

PYTORCH_VERSION="2.3.0"
TORCHVISION_VERSION="0.18.0"
PYTHON_VERSION="cp310"  # Ubuntu 22.04 ships Python 3.10

# NVIDIA's Jetson PyTorch wheel URL (JetPack 6 / L4T R36.x)
PYTORCH_WHEEL_URL="https://developer.download.nvidia.com/compute/redist/jp/v60/pytorch/torch-${PYTORCH_VERSION}a0+ebedce2.nv24.05-${PYTHON_VERSION}-${PYTHON_VERSION}-linux_aarch64.whl"

VENV_DIR="${1:-$HOME/.venvs/torch}"

# ─── Colors ────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

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

check_dependencies() {
    local missing=()
    for pkg in python3-pip python3-venv libopenblas-dev libopenmpi-dev libjpeg-dev zlib1g-dev; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        warn "Missing system packages: ${missing[*]}"
        info "Installing missing dependencies..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq "${missing[@]}"
    fi
    info "All system dependencies satisfied."
}

# ─── Virtual environment ──────────────────────────────────────────
setup_venv() {
    if [ -d "$VENV_DIR" ]; then
        warn "Virtual environment already exists at $VENV_DIR"
        read -rp "Recreate it? [y/N] " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            rm -rf "$VENV_DIR"
        else
            info "Reusing existing venv."
        fi
    fi

    if [ ! -d "$VENV_DIR" ]; then
        info "Creating virtual environment at $VENV_DIR ..."
        python3 -m venv "$VENV_DIR"
    fi

    # shellcheck disable=SC1091
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip setuptools wheel
    info "Virtual environment activated: $VENV_DIR"
}

# ─── Install PyTorch ──────────────────────────────────────────────
install_pytorch() {
    info "Installing PyTorch ${PYTORCH_VERSION} from NVIDIA wheel..."
    info "URL: $PYTORCH_WHEEL_URL"
    echo ""
    warn "If the URL is outdated, find the latest wheel at:"
    warn "  https://forums.developer.nvidia.com/t/pytorch-for-jetson/72048"
    echo ""

    pip install --no-cache-dir numpy
    pip install --no-cache-dir "$PYTORCH_WHEEL_URL" || {
        error "Failed to install PyTorch wheel."
        error "The wheel URL may have changed. Check the NVIDIA forum link above."
        error "You can also try: pip install torch --index-url https://pypi.jetson-ai-lab.dev"
        exit 1
    }
    info "PyTorch installed successfully."
}

# ─── Install TorchVision ─────────────────────────────────────────
install_torchvision() {
    info "Building TorchVision ${TORCHVISION_VERSION} from source (for CUDA aarch64 support)..."

    # TorchVision must be built from source on Jetson to link against
    # the correct CUDA and PyTorch libraries.
    local build_dir="/tmp/torchvision-build"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"

    git clone --branch "v${TORCHVISION_VERSION}" --depth 1 \
        https://github.com/pytorch/vision.git "$build_dir"

    cd "$build_dir"
    export BUILD_VERSION="${TORCHVISION_VERSION}"
    pip install --no-cache-dir pillow
    python3 setup.py install

    cd - >/dev/null
    rm -rf "$build_dir"
    info "TorchVision installed successfully."
}

# ─── Verification ─────────────────────────────────────────────────
verify_install() {
    info "Verifying installation..."
    python3 -c "
import torch
import torchvision
print(f'  PyTorch:     {torch.__version__}')
print(f'  TorchVision: {torchvision.__version__}')
print(f'  CUDA avail:  {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'  CUDA device: {torch.cuda.get_device_name(0)}')
    print(f'  CUDA ver:    {torch.version.cuda}')
    # Quick smoke test
    x = torch.randn(2, 3).cuda()
    print(f'  Tensor test: {x.device} ✓')
"
    echo ""
    info "═══════════════════════════════════════════════════════"
    info "  Done! Activate the environment with:"
    info "    source $VENV_DIR/bin/activate"
    info "═══════════════════════════════════════════════════════"
}

# ─── Main ─────────────────────────────────────────────────────────
main() {
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  PyTorch + TorchVision Installer for Jetson Orin Nano   ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""

    check_jetson
    check_cuda
    check_dependencies
    setup_venv
    install_pytorch
    install_torchvision
    verify_install
}

main "$@"
