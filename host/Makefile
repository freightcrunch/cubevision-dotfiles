# ╔══════════════════════════════════════════════════════════════════════╗
# ║  Host Machine Setup — Jetson Orin Nano (Ubuntu 22.04 aarch64)       ║
# ║                                                                      ║
# ║  Installs mold linker, latest Python, Node.js, and Rust nightly.    ║
# ║                                                                      ║
# ║  Usage:                                                              ║
# ║    make all         — install everything                             ║
# ║    make alacritty   — install Alacritty (replaces gnome-terminal)     ║
# ║    make mold        — install mold linker                            ║
# ║    make python      — install latest Python via deadsnakes PPA       ║
# ║    make node        — install latest Node.js via fnm                 ║
# ║    make rust        — install Rust nightly via rustup                ║
# ║    make deps        — install system build dependencies              ║
# ║    make info        — print installed versions                       ║
# ╚══════════════════════════════════════════════════════════════════════╝

SHELL := /bin/bash
.DEFAULT_GOAL := all
.PHONY: all deps omz alacritty mold python node rust opencv awr2944 nanoclaw info clean

# ── Latest version targets (update these as needed) ───────────────────
PYTHON_VERSION   := 3.13
NODE_MAJOR       := 22

# ── Colors ────────────────────────────────────────────────────────────
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
NC     := \033[0m

# =====================================================================
#  all — install everything in order
# =====================================================================
all: deps omz alacritty mold python node rust info

# =====================================================================
#  deps — system build dependencies required by Python, Rust, and mold
# =====================================================================
deps:
	@echo -e "$(BLUE)━━━ System Dependencies ━━━$(NC)"
	sudo apt-get update -qq
	sudo apt-get install -y -qq \
		build-essential \
		cmake \
		pkg-config \
		git \
		curl \
		wget \
		ca-certificates \
		gnupg \
		lsb-release \
		software-properties-common \
		libssl-dev \
		libffi-dev \
		libfontconfig1-dev \
		zlib1g-dev \
		libbz2-dev \
		libreadline-dev \
		libsqlite3-dev \
		libncursesw5-dev \
		libxml2-dev \
		libxmlsec1-dev \
		liblzma-dev \
		tk-dev \
		xz-utils \
		llvm \
		clang \
		lld \
		tmux \
		neovim \
		silversearcher-ag \
		tree \
		jq \
		stow \
		unzip \
		ranger
	@echo -e "$(GREEN)[✓]$(NC) System dependencies installed"

# =====================================================================
#  omz — oh-my-zsh + sensible starter plugins
# =====================================================================
omz:
	@echo -e "$(BLUE)━━━ oh-my-zsh ━━━$(NC)"
	@if [ -d "$$HOME/.oh-my-zsh" ]; then \
		echo -e "$(YELLOW)[!]$(NC) oh-my-zsh already installed"; \
	else \
		echo "Installing oh-my-zsh..."; \
		RUNZSH=no KEEP_ZSHRC=yes \
			sh -c "$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; \
		echo -e "$(GREEN)[✓]$(NC) oh-my-zsh installed"; \
	fi
	@# Install custom plugins
	@ZSH_CUSTOM="$${ZSH_CUSTOM:-$$HOME/.oh-my-zsh/custom}"; \
	for repo in \
		"zsh-users/zsh-autosuggestions" \
		"zsh-users/zsh-syntax-highlighting" \
		"zsh-users/zsh-completions" \
		"Aloxaf/fzf-tab"; \
	do \
		plugin=$$(basename "$$repo"); \
		if [ ! -d "$$ZSH_CUSTOM/plugins/$$plugin" ]; then \
			git clone "https://github.com/$$repo" "$$ZSH_CUSTOM/plugins/$$plugin"; \
		fi; \
	done
	@echo -e "$(GREEN)[✓]$(NC) oh-my-zsh plugins installed"
	@echo "  Bundled:  git tmux command-not-found colored-man-pages extract z"
	@echo "  Custom:   zsh-autosuggestions zsh-syntax-highlighting zsh-completions fzf-tab"

# =====================================================================
#  alacritty — GPU-accelerated terminal (replaces gnome-terminal)
# =====================================================================
alacritty:
	@echo -e "$(BLUE)━━━ Alacritty ━━━$(NC)"
	@if command -v alacritty &>/dev/null; then \
		echo -e "$(YELLOW)[!]$(NC) Alacritty already installed: $$(alacritty --version)"; \
	else \
		echo "Installing Alacritty..."; \
		sudo apt-get update -qq; \
		sudo apt-get install -y -qq alacritty 2>/dev/null || { \
			echo "apt package not available, installing via cargo..."; \
			sudo apt-get install -y -qq \
				libfreetype6-dev libfontconfig1-dev libxcb-xfixes0-dev libxkbcommon-dev; \
			. "$$HOME/.cargo/env" && cargo install alacritty; \
		}; \
		echo -e "$(GREEN)[✓]$(NC) Alacritty installed: $$(alacritty --version)"; \
	fi
	@# Set as default terminal
	@if command -v update-alternatives &>/dev/null; then \
		sudo update-alternatives --install /usr/bin/x-terminal-emulator \
			x-terminal-emulator $$(which alacritty) 50 2>/dev/null || true; \
		sudo update-alternatives --set x-terminal-emulator $$(which alacritty) 2>/dev/null || true; \
		echo -e "$(GREEN)[✓]$(NC) Alacritty set as default terminal emulator"; \
	fi

# =====================================================================
#  mold — fast linker (significantly speeds up Rust/C++ linking)
# =====================================================================
mold:
	@echo -e "$(BLUE)━━━ mold Linker ━━━$(NC)"
	@if command -v mold &>/dev/null; then \
		echo -e "$(YELLOW)[!]$(NC) mold already installed: $$(mold --version)"; \
	else \
		echo "Installing mold from apt..."; \
		sudo apt-get update -qq; \
		sudo apt-get install -y -qq mold 2>/dev/null || { \
			echo "apt package not available, building mold from source..."; \
			$(MAKE) _mold_from_source; \
		}; \
		echo -e "$(GREEN)[✓]$(NC) mold installed: $$(mold --version)"; \
	fi

_mold_from_source:
	@echo "Cloning mold repository..."
	sudo apt-get install -y -qq libstdc++-12-dev
	git clone --depth 1 https://github.com/rui314/mold.git /tmp/mold-build
	cd /tmp/mold-build && \
		cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -B build && \
		cmake --build build -j$$(nproc) && \
		sudo cmake --install build
	rm -rf /tmp/mold-build

# =====================================================================
#  python — latest Python via deadsnakes PPA
# =====================================================================
python:
	@echo -e "$(BLUE)━━━ Python $(PYTHON_VERSION) ━━━$(NC)"
	@if python$(PYTHON_VERSION) --version &>/dev/null; then \
		echo -e "$(YELLOW)[!]$(NC) Python $(PYTHON_VERSION) already installed: $$(python$(PYTHON_VERSION) --version)"; \
	else \
		sudo add-apt-repository -y ppa:deadsnakes/ppa; \
		sudo apt-get update -qq; \
		sudo apt-get install -y -qq \
			python$(PYTHON_VERSION) \
			python$(PYTHON_VERSION)-venv \
			python$(PYTHON_VERSION)-dev \
			python$(PYTHON_VERSION)-distutils; \
		echo -e "$(GREEN)[✓]$(NC) Python $(PYTHON_VERSION) installed"; \
	fi
	@# Install pip for the new Python version
	@if ! python$(PYTHON_VERSION) -m pip --version &>/dev/null; then \
		curl -sSL https://bootstrap.pypa.io/get-pip.py | python$(PYTHON_VERSION); \
	fi
	@# Install essential Python tools
	python$(PYTHON_VERSION) -m pip install --user --upgrade pip setuptools wheel
	python$(PYTHON_VERSION) -m pip install --user ruff uv
	@echo -e "$(GREEN)[✓]$(NC) Python tools installed (ruff, uv)"

# =====================================================================
#  node — latest Node.js LTS via fnm (Fast Node Manager)
# =====================================================================
node:
	@echo -e "$(BLUE)━━━ Node.js $(NODE_MAJOR) ━━━$(NC)"
	@if command -v fnm &>/dev/null; then \
		echo -e "$(YELLOW)[!]$(NC) fnm already installed"; \
	else \
		echo "Installing fnm (Fast Node Manager)..."; \
		curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell; \
		echo -e "$(GREEN)[✓]$(NC) fnm installed"; \
	fi
	@# Source fnm and install Node
	@export PATH="$$HOME/.local/share/fnm:$$PATH" && \
		eval "$$(fnm env)" && \
		fnm install $(NODE_MAJOR) && \
		fnm default $(NODE_MAJOR) && \
		fnm use $(NODE_MAJOR) && \
		echo -e "$(GREEN)[✓]$(NC) Node.js $$(node --version) installed" && \
		npm install -g npm@latest && \
		echo -e "$(GREEN)[✓]$(NC) npm $$(npm --version) installed"

# =====================================================================
#  rust — Rust nightly toolchain via rustup with essential components
# =====================================================================
rust:
	@echo -e "$(BLUE)━━━ Rust (nightly) ━━━$(NC)"
	@# Install rustup if not present
	@if ! command -v rustup &>/dev/null; then \
		echo "Installing rustup..."; \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly; \
		. "$$HOME/.cargo/env"; \
	fi
	@# Ensure nightly is installed and set as default
	@. "$$HOME/.cargo/env" && \
		rustup toolchain install nightly && \
		rustup default nightly && \
		rustup component add --toolchain nightly \
			clippy \
			rustfmt \
			rust-analyzer \
			rust-src \
			llvm-tools && \
		echo -e "$(GREEN)[✓]$(NC) Rust nightly installed: $$(rustc --version)"
	@# Install common cargo tools
	@. "$$HOME/.cargo/env" && \
		cargo install --locked cargo-watch cargo-expand cargo-edit cargo-nextest 2>/dev/null || true && \
		echo -e "$(GREEN)[✓]$(NC) Cargo tools installed"
	@# Configure mold as the default linker if available
	@if command -v mold &>/dev/null; then \
		mkdir -p "$$HOME/.cargo"; \
		if ! grep -q 'fuse-ld=mold' "$$HOME/.cargo/config.toml" 2>/dev/null; then \
			echo "" >> "$$HOME/.cargo/config.toml"; \
			echo "[target.aarch64-unknown-linux-gnu]" >> "$$HOME/.cargo/config.toml"; \
			echo 'linker = "clang"' >> "$$HOME/.cargo/config.toml"; \
			echo 'rustflags = ["-C", "link-arg=-fuse-ld=mold"]' >> "$$HOME/.cargo/config.toml"; \
			echo -e "$(GREEN)[✓]$(NC) Cargo configured to use mold linker"; \
		fi; \
	fi

# =====================================================================
#  opencv — OpenCV with CUDA from source (latest: 4.13.0)
# =====================================================================
opencv:
	@echo -e "$(BLUE)━━━ OpenCV (CUDA build) ━━━$(NC)"
	@DOTFILES="$$(cd "$$(dirname $$0)/.." 2>/dev/null && pwd || cd .. && pwd)"; \
	if [ -f "$$DOTFILES/opencv/setup-opencv-jetson.sh" ]; then \
		chmod +x "$$DOTFILES/opencv/setup-opencv-jetson.sh"; \
		bash "$$DOTFILES/opencv/setup-opencv-jetson.sh"; \
	else \
		echo -e "$(RED)[✗]$(NC) opencv/setup-opencv-jetson.sh not found"; \
		echo "  Run from the dotfiles root: bash opencv/setup-opencv-jetson.sh"; \
	fi

# =====================================================================
#  awr2944 — TI AWR2944 radar dev environment
# =====================================================================
awr2944:
	@echo -e "$(BLUE)━━━ AWR2944 Radar Dev Environment ━━━$(NC)"
	@DOTFILES="$$(cd "$$(dirname $$0)/.." 2>/dev/null && pwd || cd .. && pwd)"; \
	if [ -f "$$DOTFILES/awr2944/scripts/bootstrap-linux-arm64.sh" ]; then \
		chmod +x "$$DOTFILES/awr2944/scripts/"*.sh; \
		echo -e "$(GREEN)[✓]$(NC) AWR2944 scripts ready at: $$DOTFILES/awr2944/"; \
		echo "  Bootstrap:  bash $$DOTFILES/awr2944/scripts/bootstrap-linux-arm64.sh"; \
		echo "  Verify:     bash $$DOTFILES/awr2944/scripts/verify-env.sh"; \
		echo "  Docker SDK: cd $$DOTFILES/awr2944/docker && docker compose build"; \
	else \
		echo -e "$(RED)[✗]$(NC) awr2944/ directory not found"; \
	fi

# =====================================================================
#  nanoclaw — OpenClaw AI gateway (latest stable: 2026.3.28)
# =====================================================================
nanoclaw:
	@echo -e "$(BLUE)━━━ NanoClaw (OpenClaw) ━━━$(NC)"
	@if command -v openclaw &>/dev/null; then \
		echo -e "$(YELLOW)[!]$(NC) OpenClaw already installed: $$(openclaw --version)"; \
		echo "Upgrading to latest..."; \
	fi
	sudo env "PATH=$$(dirname $$(command -v node)):$$PATH" npm install -g openclaw@latest
	@echo -e "$(GREEN)[✓]$(NC) OpenClaw $$(openclaw --version) installed"
	@echo "  Run the full setup:  bash nanoclaw/setup-openclaw.sh"
	@echo "  Or with Ollama:      bash nanoclaw/setup-openclaw.sh --with-ollama"

# =====================================================================
#  info — print installed versions
# =====================================================================
info:
	@echo ""
	@echo -e "$(BLUE)━━━ Installed Versions ━━━$(NC)"
	@command -v alacritty &>/dev/null && echo -e "  alacritty: $$(alacritty --version)" || echo "  alacritty: not installed"
	@command -v mold &>/dev/null && echo -e "  mold:    $$(mold --version)" || echo "  mold:    not installed"
	@python$(PYTHON_VERSION) --version 2>/dev/null && true || echo "  python:  not installed"
	@command -v ruff &>/dev/null && echo -e "  ruff:    $$(ruff --version)" || echo "  ruff:    not installed"
	@. "$$HOME/.cargo/env" 2>/dev/null && echo -e "  rustc:   $$(rustc --version)" || echo "  rustc:   not installed"
	@export PATH="$$HOME/.local/share/fnm:$$PATH" && \
		eval "$$(fnm env 2>/dev/null)" 2>/dev/null && \
		echo -e "  node:    $$(node --version)" || echo "  node:    not installed"
	@command -v openclaw &>/dev/null && echo -e "  openclaw: $$(openclaw --version)" || echo "  openclaw: not installed"
	@echo ""

# =====================================================================
#  clean — remove installed toolchains (use with caution)
# =====================================================================
clean:
	@echo -e "$(YELLOW)[!] This will remove rustup, fnm, and their toolchains.$(NC)"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@# Rust
	@if command -v rustup &>/dev/null; then rustup self uninstall -y; fi
	@# fnm
	@rm -rf "$$HOME/.local/share/fnm"
	@echo -e "$(GREEN)[✓]$(NC) Cleaned up toolchains"
