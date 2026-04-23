#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  WSL2 Environment Setup — Windows Dev Machine                       ║
# ║  AMD Ryzen 7 260 (8c/16t) · 16 GB · Radeon 780M                    ║
# ║                                                                      ║
# ║  Usage:  bash wsl/install.sh [--all | --packages | --zsh | --nvim   ║
# ║            | --rust | --python | --node | --docker | --cuda]        ║
# ║                                                                      ║
# ║  With no arguments, installs everything.                             ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"

# ─── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*" >&2; }
section() { echo -e "\n${BLUE}━━━ $* ━━━${NC}"; }

# ─── Helpers ─────────────────────────────────────────────────────────
symlink() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        warn "Backing up existing $dst → ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi
    ln -s "$src" "$dst"
    info "Linked $dst → $src"
}

# ─── System packages ────────────────────────────────────────────────
install_packages() {
    section "System Packages (WSL2)"
    local pkgs=(
        # shell
        zsh fzf zoxide
        # dev tools
        git curl wget build-essential cmake pkg-config ninja-build
        # compilers
        clang lld llvm gcc g++
        # python
        python3-pip python3-venv python3-dev pipx
        # rust dependencies (openssl, fontconfig, alsa-sys, pkg-config)
        libssl-dev libfontconfig1-dev pkg-config
        libasound2-dev libatk1.0-dev libgtk-3-dev
        # ML / compute dependencies
        libopenblas-dev libopenmpi-dev libjpeg-dev zlib1g-dev
        libhdf5-dev libnccl2 libnccl-dev
        # 3D / point cloud / rendering
        libeigen3-dev libflann-dev libboost-all-dev libvtk9-dev
        libpcl-dev libglfw3-dev libglew-dev libglm-dev
        mesa-utils vulkan-tools libvulkan-dev mesa-vulkan-drivers
        # streaming / media
        ffmpeg v4l-utils
        # wasm toolchain
        binaryen wabt
        # terminal / editors
        tmux neovim
        # search & file tools
        ripgrep fd-find bat tree jq stow unzip
        # databases
        postgresql-client libpq-dev sqlite3 libsqlite3-dev
        # network
        openssh-client ca-certificates gnupg lsb-release
        # misc
        htop fastfetch
    )

    info "Updating package lists..."
    sudo apt-get update -qq

    info "Installing packages..."
    sudo apt-get install -y -qq "${pkgs[@]}" 2>/dev/null || {
        warn "Some packages may not be available. Installing individually..."
        for pkg in "${pkgs[@]}"; do
            sudo apt-get install -y -qq "$pkg" 2>/dev/null || warn "Skipped: $pkg"
        done
    }

    # make zsh the default shell
    if [ "$SHELL" != "$(which zsh)" ]; then
        info "Setting zsh as default shell..."
        chsh -s "$(which zsh)"
    fi

    info "System packages installed."
}

# ─── Zsh ─────────────────────────────────────────────────────────────
install_zsh() {
    section "Zsh Configuration (WSL2)"
    mkdir -p "$HOME/.local/state/zsh"
    mkdir -p "$HOME/.cache/zsh"

    symlink "$DOTFILES/wsl/zsh/.zshrc"  "$HOME/.zshrc"
    symlink "$DOTFILES/wsl/zsh/.zshenv" "$HOME/.zshenv"

    # install zinit plugin manager
    local ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
    if [[ ! -d "$ZINIT_HOME" ]]; then
        info "Installing zinit..."
        mkdir -p "$(dirname "$ZINIT_HOME")"
        git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    else
        info "zinit already installed."
    fi

    info "Zsh config installed. Run 'p10k configure' after first launch."
}

# ─── Neovim (LazyVim) ───────────────────────────────────────────────
install_nvim() {
    section "Neovim + LazyVim (WSL2)"

    local nvim_config="$HOME/.config/nvim"

    # back up existing config
    if [ -d "$nvim_config" ] && [ ! -L "$nvim_config" ]; then
        warn "Backing up existing nvim config → ${nvim_config}.bak"
        mv "$nvim_config" "${nvim_config}.bak"
    fi

    # remove old symlink if present
    [ -L "$nvim_config" ] && rm "$nvim_config"

    # symlink our LazyVim config
    symlink "$DOTFILES/wsl/nvim" "$nvim_config"

    # install latest neovim if the apt version is too old (LazyVim needs 0.9+)
    local nvim_ver
    nvim_ver=$(nvim --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+' || echo "0.0")
    if (( $(echo "$nvim_ver < 0.9" | bc -l 2>/dev/null || echo 1) )); then
        info "Installing latest Neovim from GitHub releases..."
        curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
        sudo rm -rf /opt/nvim
        sudo tar -C /opt -xzf nvim-linux64.tar.gz
        sudo ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
        rm -f nvim-linux64.tar.gz
        info "Neovim $(nvim --version | head -1) installed"
    else
        info "Neovim $nvim_ver already meets LazyVim requirements."
    fi

    info "LazyVim config installed. Run 'nvim' to bootstrap plugins."
}

# ─── Tmux ────────────────────────────────────────────────────────────
install_tmux() {
    section "Tmux Configuration (WSL2)"
    symlink "$DOTFILES/wsl/tmux/tmux.conf" "$HOME/.tmux.conf"
    info "Tmux config installed."
}

# ─── Rust ────────────────────────────────────────────────────────────
install_rust() {
    section "Rust Toolchain (WSL2)"

    if ! command -v rustup &>/dev/null; then
        info "Installing Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
        source "$HOME/.cargo/env"
    else
        info "Rust already installed: $(rustc --version)"
    fi

    # stable + nightly toolchains
    rustup toolchain install nightly 2>/dev/null || true
    rustup component add clippy rustfmt rust-analyzer rust-src llvm-tools 2>/dev/null || true
    rustup component add --toolchain nightly clippy rustfmt rust-analyzer rust-src llvm-tools 2>/dev/null || true

    # wasm targets
    rustup target add wasm32-unknown-unknown 2>/dev/null || true
    rustup target add --toolchain nightly wasm32-unknown-unknown 2>/dev/null || true

    # cargo tools
    info "Installing cargo tools (this may take a while)..."
    cargo install --locked cargo-watch cargo-expand cargo-nextest 2>/dev/null || true
    cargo install --locked cargo-leptos 2>/dev/null || true
    cargo install --locked wasm-bindgen-cli 2>/dev/null || true
    cargo install --locked wasmtime-cli 2>/dev/null || true
    cargo install --locked sccache 2>/dev/null || true

    info "Rust toolchain configured (stable + nightly, wasm, cargo-leptos, wasmtime, sccache)."
}

# ─── Python ──────────────────────────────────────────────────────────
install_python() {
    section "Python Configuration (WSL2)"

    mkdir -p "$HOME/.config/pip"
    mkdir -p "$HOME/.config/ruff"

    # install ruff + uv globally
    if ! command -v ruff &>/dev/null; then
        info "Installing ruff + uv..."
        pip install --user --break-system-packages ruff uv 2>/dev/null || \
        pip install --user ruff uv 2>/dev/null || \
        warn "Could not install ruff/uv globally."
    fi

    # pipx for isolated CLI tools
    if command -v pipx &>/dev/null; then
        pipx ensurepath 2>/dev/null || true
    fi

    info "Python config installed (ruff, uv, pipx)."
}

# ─── Node.js ─────────────────────────────────────────────────────────
install_node() {
    section "Node.js Configuration (WSL2)"

    # install fnm (Fast Node Manager)
    if ! command -v fnm &>/dev/null; then
        info "Installing fnm..."
        curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
        export PATH="$HOME/.local/share/fnm:$PATH"
        eval "$(fnm env)"
    fi

    fnm install --lts
    fnm default lts-latest

    # global tools (pnpm installed via corepack for better version mgmt)
    corepack enable 2>/dev/null || true
    corepack prepare pnpm@latest --activate 2>/dev/null || true
    npm install -g typescript ts-node prettier eslint 2>/dev/null || true

    info "Node.js $(node --version) configured (pnpm via corepack)."
}

# ─── Docker Integration ─────────────────────────────────────────────
install_docker() {
    section "Docker Integration (WSL2)"

    # Docker Desktop on Windows handles the daemon; we just need the CLI tools in WSL2
    if command -v docker &>/dev/null; then
        info "Docker CLI already available: $(docker --version)"
    else
        info "Installing Docker CLI + Compose plugin..."

        # add Docker's official GPG key
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
            sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        # add Docker apt repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
          https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update -qq
        sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin

        # add user to docker group
        sudo usermod -aG docker "$USER"
        info "Docker installed. Log out/in to use without sudo."
    fi

    # install NVIDIA Container Toolkit (for GPU passthrough in Docker)
    if ! command -v nvidia-container-toolkit &>/dev/null; then
        info "Installing NVIDIA Container Toolkit..."
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
            sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
        sudo apt-get update -qq
        sudo apt-get install -y -qq nvidia-container-toolkit 2>/dev/null || \
            warn "NVIDIA Container Toolkit install failed (NVIDIA GPU may not be present)"

        # configure Docker to use NVIDIA runtime
        if command -v nvidia-ctk &>/dev/null; then
            sudo nvidia-ctk runtime configure --runtime=docker 2>/dev/null || true
            sudo systemctl restart docker 2>/dev/null || true
            info "NVIDIA Container Toolkit configured."
        fi
    else
        info "NVIDIA Container Toolkit already installed."
    fi

    info "Docker integration configured."
}

# ─── CUDA Toolkit (WSL2) ────────────────────────────────────────────
install_cuda() {
    section "CUDA Toolkit (WSL2)"

    # NOTE: CUDA on WSL2 requires an NVIDIA GPU with Windows driver that
    # supports WSL2 GPU passthrough. The GPU driver lives on the Windows
    # side — do NOT install a Linux GPU driver inside WSL2.
    #
    # Current system: AMD Radeon 780M (iGPU) — CUDA will not function
    # without an NVIDIA GPU. This section is included for when an NVIDIA
    # GPU (discrete or eGPU) is added to the system.

    # check for NVIDIA GPU
    if ! (lspci 2>/dev/null | grep -qi nvidia) && ! [ -e /usr/lib/wsl/lib/nvidia-smi ]; then
        warn "No NVIDIA GPU detected in WSL2."
        warn "CUDA toolkit will be installed but won't function without an NVIDIA GPU."
        warn "Install NVIDIA Windows driver with WSL2 support from:"
        warn "  https://developer.nvidia.com/cuda/wsl"
        echo ""
    fi

    # install CUDA keyring and toolkit via network repo (always gets latest)
    if ! dpkg -l cuda-toolkit-* 2>/dev/null | grep -q "^ii"; then
        info "Installing CUDA toolkit (latest) for WSL-Ubuntu..."
        wget -q https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb \
            -O /tmp/cuda-keyring.deb
        sudo dpkg -i /tmp/cuda-keyring.deb
        rm -f /tmp/cuda-keyring.deb
        sudo apt-get update -qq
        sudo apt-get install -y -qq cuda-toolkit 2>/dev/null || \
            warn "CUDA toolkit install failed — check GPU availability"
    else
        info "CUDA toolkit already installed."
    fi

    # install cuDNN
    if ! dpkg -l libcudnn* 2>/dev/null | grep -q "^ii"; then
        info "Installing cuDNN..."
        sudo apt-get install -y -qq libcudnn9-cuda-12 libcudnn9-dev-cuda-12 2>/dev/null || \
            warn "cuDNN install failed — CUDA toolkit may not be installed"
    else
        info "cuDNN already installed."
    fi

    # install TensorRT
    if ! dpkg -l libnvinfer* 2>/dev/null | grep -q "^ii"; then
        info "Installing TensorRT..."
        sudo apt-get install -y -qq libnvinfer-dev libnvinfer-plugin-dev 2>/dev/null || \
            warn "TensorRT install failed"
    else
        info "TensorRT already installed."
    fi

    info "CUDA environment configured."
    info "Verify with: nvcc --version && python3 -c 'import torch; print(torch.cuda.is_available())'"
}

# ─── Git config ──────────────────────────────────────────────────────
install_git() {
    section "Git Configuration (WSL2)"

    if ! git config --global user.name &>/dev/null; then
        warn "Git user.name not set. Configure with:"
        warn "  git config --global user.name 'Your Name'"
        warn "  git config --global user.email 'you@example.com'"
    fi

    git config --global init.defaultBranch main
    git config --global pull.rebase true
    git config --global core.autocrlf input
    git config --global core.editor nvim
    git config --global diff.algorithm histogram

    info "Git global config updated."
}

# ─── .NET SDK (C# development) ──────────────────────────────────────
install_dotnet() {
    section ".NET SDK (WSL2)"

    if ! command -v dotnet &>/dev/null; then
        info "Installing .NET SDK..."
        wget -q https://dot.net/v1/dotnet-install.sh -O /tmp/dotnet-install.sh
        chmod +x /tmp/dotnet-install.sh
        /tmp/dotnet-install.sh --channel LTS --install-dir "$HOME/.dotnet"
        rm -f /tmp/dotnet-install.sh
        info ".NET SDK installed to ~/.dotnet"
    else
        info ".NET SDK already installed: $(dotnet --version)"
    fi
}

# ─── ML / Point Cloud / Finetuning ─────────────────────────────────
install_ml() {
    section "ML / Point Cloud / Finetuning (WSL2)"

    info "Installing Python ML & point cloud packages..."
    pip install --user --break-system-packages \
        jupyter jupyterlab notebook 2>/dev/null || \
    pip install --user \
        jupyter jupyterlab notebook 2>/dev/null || \
        warn "Jupyter install failed"

    # Point cloud & 3D visualization
    pip install --user --break-system-packages \
        open3d laspy pyntcloud trimesh plyfile pylas 2>/dev/null || \
    pip install --user \
        open3d laspy pyntcloud trimesh plyfile pylas 2>/dev/null || \
        warn "Point cloud packages failed"

    # PyTorch (CUDA 12.4 — adjust index-url for your GPU)
    pip install --user --break-system-packages \
        torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/cu124 2>/dev/null || \
        warn "PyTorch install failed — install manually with correct CUDA version"

    # Finetuning / LLM stack
    pip install --user --break-system-packages \
        transformers accelerate datasets peft trl \
        bitsandbytes sentencepiece protobuf safetensors \
        einops flash-attn scipy 2>/dev/null || \
    pip install --user \
        transformers accelerate datasets peft trl \
        bitsandbytes sentencepiece protobuf safetensors \
        einops scipy 2>/dev/null || \
        warn "ML finetuning packages failed"

    # Visualization
    pip install --user --break-system-packages \
        matplotlib plotly dash polars pandas 2>/dev/null || \
    pip install --user \
        matplotlib plotly dash polars pandas 2>/dev/null || \
        warn "Visualization packages failed"

    info "ML / Point Cloud / Finetuning packages installed."
}

# ─── Cloud CLIs & DB Tools ─────────────────────────────────────────
install_cloud() {
    section "Cloud CLIs & Database Tools (WSL2)"

    # Azure CLI
    if ! command -v az &>/dev/null; then
        info "Installing Azure CLI..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash 2>/dev/null || \
            warn "Azure CLI install failed"
    else
        info "Azure CLI already installed: $(az --version 2>/dev/null | head -1)"
    fi

    # AWS CLI v2
    if ! command -v aws &>/dev/null; then
        info "Installing AWS CLI v2..."
        curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
        unzip -qo /tmp/awscliv2.zip -d /tmp/aws-install
        sudo /tmp/aws-install/aws/install --update 2>/dev/null || \
            warn "AWS CLI install failed"
        rm -rf /tmp/awscliv2.zip /tmp/aws-install
    else
        info "AWS CLI already installed: $(aws --version 2>/dev/null)"
    fi

    # Cloudflare Workers CLI (wrangler) via npm
    if ! command -v wrangler &>/dev/null; then
        info "Installing Cloudflare Wrangler..."
        npm install -g wrangler 2>/dev/null || \
            warn "Wrangler install failed — ensure Node.js is installed"
    else
        info "Wrangler already installed: $(wrangler --version 2>/dev/null)"
    fi

    # Microsoft SQL Server tools (sqlcmd, bcp)
    if ! command -v sqlcmd &>/dev/null; then
        info "Installing mssql-tools..."
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg 2>/dev/null || true
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/$(lsb_release -rs)/prod $(lsb_release -cs) main" | \
            sudo tee /etc/apt/sources.list.d/mssql-release.list > /dev/null
        sudo apt-get update -qq
        sudo ACCEPT_EULA=Y apt-get install -y -qq mssql-tools18 unixodbc-dev 2>/dev/null || \
            warn "mssql-tools install failed"
    else
        info "mssql-tools already installed."
    fi

    info "Cloud CLIs & database tools configured."
}

# ─── Main ────────────────────────────────────────────────────────────
usage() {
    echo "Usage: $0 [--all | --packages | --zsh | --nvim | --tmux | --rust"
    echo "           | --python | --node | --docker | --cuda | --dotnet"
    echo "           | --cloud | --ml | --git]"
    echo "  No arguments = install everything"
}

main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  WSL2 Environment Setup — Windows Dev Machine               ║"
    echo "║  AMD Ryzen 7 260 · 8c/16t · 16 GB · Radeon 780M            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    info "Dotfiles directory: $DOTFILES"

    if [ $# -eq 0 ] || [ "$1" = "--all" ]; then
        install_packages
        install_git
        install_zsh
        install_nvim
        install_tmux
        install_rust
        install_python
        install_node
        install_dotnet
        install_cloud
        install_ml
        install_docker
        install_cuda
    else
        for arg in "$@"; do
            case "$arg" in
                --packages) install_packages ;;
                --zsh)      install_zsh ;;
                --nvim)     install_nvim ;;
                --tmux)     install_tmux ;;
                --rust)     install_rust ;;
                --python)   install_python ;;
                --node)     install_node ;;
                --docker)   install_docker ;;
                --cuda)     install_cuda ;;
                --dotnet)   install_dotnet ;;
                --cloud)    install_cloud ;;
                --ml)       install_ml ;;
                --git)      install_git ;;
                --help|-h)  usage; exit 0 ;;
                *)          error "Unknown option: $arg"; usage; exit 1 ;;
            esac
        done
    fi

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✓ WSL2 environment setup complete!                         ║"
    echo "║                                                              ║"
    echo "║  Next steps:                                                 ║"
    echo "║  1. Run: exec zsh                                            ║"
    echo "║  2. Run 'p10k configure' to set up your prompt              ║"
    echo "║  3. Run 'nvim' to bootstrap LazyVim plugins                  ║"
    echo "║  4. Verify Docker: docker run hello-world                    ║"
    echo "║  5. Verify CUDA: nvcc --version                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
}

main "$@"
