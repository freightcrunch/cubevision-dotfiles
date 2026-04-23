```
 ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │                                                                                                              │
 │                                                                                                              │
 │                            ,---,                         ,--,                 ,--,                            │
 │                      ,--,,---.'|                       ,--.'|               ,--.'|    ,---.        ,---,      │
 │                    ,'_ /||   | :                  .---.|  |,      .--.--.   |  |,    '   ,'\   ,-+-. /  |     │
 │      ,---.    .--. |  | ::   : :      ,---.     /.  ./|`--'_     /  /    '  `--'_   /   /   | ,--.'|'   |    │
 │     /     \ ,'_ /| :  . |:     |,-.  /     \  .-' . ' |,' ,'|   |  :  /`./  ,' ,'| .   ; ,. :|   |  ,"' |   │
 │    /    / ' |  ' | |  . .|   : '  | /    /  |/___/ \: |'  | |   |  :  ;_    '  | | '   | |: :|   | /  | |   │
 │   .    ' /  |  | ' |  | ||   |  / :.    ' / |.   \  ' .|  | :    \  \    `. |  | : '   | .; :|   | |  | |   │
 │   '   ; :__ :  | : ;  ; |'   : |: |'   ;   /| \   \   ''  : |__   `----.   \'  : |_|   :    ||   | |  |/    │
 │   '   | '.'|'  :  `--'   \   | '/ :'   |  / |  \   \   |  | '.'| /  /`--'  /|  | '.'\   \  / |   | |--'     │
 │   |   :    ::  ,      .-./   :    ||   :    |   \   \ |;  :    ;'--'.     / ;  :    ;`----'  |   |/         │
 │    \   \  /  `--`----'   /    \  /  \   \  /     '---" |  ,   /   `--'---'  |  ,   /         '---'          │
 │     `----'               `-'----'    `----'             ---`-'               ---`-'                          │
 │                                                                                                              │
 │──────────────────────────────────────────────────────────────────────────────────────────────────────────────│
 │                                                                                                              │
 │   platform ......... NVIDIA Jetson Orin Nano SUPER 8GB                                                       │
 │   os ............... Ubuntu 22.04 LTS (aarch64)                                                              │
 │   wm ............... bspwm + polybar + picom                                                                 │
 │   shell ............ zsh + oh-my-zsh + p10k                                                                  │
 │   editor ........... neovim                                                                                  │
 │   toolchain ........ rust · python · node                                                                    │
 │   ai ............... ollama + openclaw                                                                       │
 │                                                                                                              │
 └──────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

# Dotfiles — Jetson Orin Nano

Configuration files for a development environment on **NVIDIA Jetson Orin Nano** running Ubuntu 22.04 LTS (aarch64).

## Hardware

| Spec       | Value                              |
|------------|------------------------------------|
| Host       | NVIDIA Jetson Orin Nano            |
| OS         | Ubuntu 22.04.5 LTS aarch64        |
| Kernel     | 5.15.148-tegra                     |
| CPU        | ARMv8 rev 1 (v8l) — 6 cores       |
| Memory     | 8 GB                               |
| Display    | 1920×1080                          |

## What's Included

```
dotfiles/
├── zsh/                  # Zsh shell config (zinit, p10k, aliases)
│   ├── .zshrc
│   └── .zshenv
├── alacritty/            # Alacritty terminal emulator
│   └── alacritty.toml
├── tmux/                 # Tmux terminal multiplexer
│   └── tmux.conf
├── bspwm/                # bspwm window manager
│   └── bspwmrc
├── sxhkd/                # Keybindings for bspwm
│   └── sxhkdrc
├── picom/                # Compositor (lightweight for Jetson)
│   └── picom.conf
├── polybar/              # Status bar for bspwm
│   ├── config.ini
│   └── launch.sh
├── rust/                 # Rust toolchain config
│   ├── cargo-config.toml
│   ├── rustfmt.toml
│   └── clippy.toml
├── python/               # Python dev config
│   ├── pip.conf
│   ├── ruff.toml
│   └── pyproject-template.toml
├── javascript/           # JS/Node config
│   ├── npmrc
│   ├── .eslintrc.json
│   └── .prettierrc.json
├── ranger/               # Ranger file manager config
│   ├── rc.conf
│   ├── rifle.conf
│   └── scope.sh
├── pytorch/              # PyTorch/TorchVision Jetson installer
│   ├── setup-pytorch-jetson.sh
│   └── torch-test.py
├── mmwave/               # mmWave radar driver (RS-2944A / AWR2944)
│   ├── README.md
│   ├── 99-mmwave-radar.rules  # udev rules for CP2105 USB-UART
│   └── setup-mmwave.sh        # Driver + deps installer
├── dev/                  # Nix flake dev environment
│   ├── README.md
│   ├── flake.nix
│   ├── Cross.toml          # Cross-compilation targets
│   └── hello-server/       # Starter Axum + Leptos app
│       ├── Cargo.toml
│       ├── .env
│       └── src/main.rs
├── qdrant/               # Qdrant vector database
│   ├── README.md
│   ├── config.yaml
│   └── setup-qdrant.sh
├── sqlite/               # SQLite relational database
│   ├── README.md
│   ├── sqliterc
│   └── setup-sqlite.sh
├── neo4j/                # Neo4j graph database
│   ├── README.md
│   ├── neo4j.conf
│   └── setup-neo4j.sh
├── nanoclaw/             # OpenClaw AI gateway for Jetson
│   ├── README.md
│   ├── setup-openclaw.sh
│   ├── openclaw.service
│   └── openclaw.json
├── guides/               # Jetson Orin Nano SUPER quick-ref guides
│   ├── README.md            # Index
│   ├── 01-flash-system.md   # Flash & upgrade to SUPER
│   ├── 02-environment.md    # System packages, SSH, VS Code
│   ├── 03-cuda-cudnn.md     # Verify CUDA & cuDNN
│   ├── 04-jtop.md           # jetson-stats monitoring
│   ├── 05-docker.md         # NVIDIA Container Runtime
│   ├── 06-gpio.md           # Jetson.GPIO library
│   ├── 07-camera.md         # CSI & USB camera pipelines
│   ├── 08-pytorch.md        # PyTorch for JetPack
│   ├── 09-tensorrt.md       # Model conversion & inference
│   ├── 10-yolo.md           # YOLO deployment
│   ├── 11-ollama-llm.md     # Local LLM inference
│   ├── 12-deepstream.md     # Video analytics
│   └── 13-performance.md    # Power modes, clocks, tuning
├── host/                 # Host machine setup (Makefile)
│   └── Makefile
├── scripts/
│   ├── install.sh        # Main installer (symlinks + packages)
│   ├── select-bspwm.sh   # Switch to bspwm from GDM3
│   └── fix-snap-browsers.sh  # Fix Snap 2.70+ browser bug
└── README.md
```

## Quick Start

```bash
git clone https://github.com/<you>/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x scripts/install.sh
./scripts/install.sh
```

### Install specific modules only

```bash
./scripts/install.sh --zsh       # just zsh config
./scripts/install.sh --bspwm     # just bspwm + sxhkd
./scripts/install.sh --rust      # rust toolchain + config
./scripts/install.sh --python    # pip, ruff config
./scripts/install.sh --js        # nvm, npm, eslint, prettier
./scripts/install.sh --pytorch   # prints PyTorch install instructions
./scripts/install.sh --mmwave    # mmWave radar driver setup
./scripts/install.sh --packages  # apt packages only
```

## Dev Environment (Nix Flake)

The `dev/` directory contains a reproducible Nix flake that mirrors all host dependencies:

```bash
cd dev/
nix develop
```

See `dev/README.md` for Nix installation instructions.

### Starter Server (Axum + Leptos)

A minimal full-stack Rust server lives in `dev/hello-server/`:

```bash
cd dev/hello-server
cargo run
# => http://localhost:3000 — "Hello from the development"
```

The `APP_ENV` value is read from `.env` (defaults to `development`). Swap to `.env.production` for production builds.

### Cross-Compilation

`dev/Cross.toml` configures [`cross`](https://github.com/cross-rs/cross) for three targets:

```bash
cargo install cross --git https://github.com/cross-rs/cross
cross build --target x86_64-unknown-linux-gnu --release
cross build --target aarch64-unknown-linux-gnu --release
# macOS: cargo zigbuild --target aarch64-apple-darwin --release
```

| Target                        | Platform                          |
|-------------------------------|-----------------------------------|
| `x86_64-unknown-linux-gnu`    | Standard x86_64 Linux             |
| `aarch64-unknown-linux-gnu`   | ARM64 Linux (Jetson, RPi, etc.)   |
| `aarch64-apple-darwin`        | Apple Silicon (M1/M2/M3/M4 Mac)   |

## Host Machine Setup (Makefile)

The `host/` directory contains a Makefile to install mold, latest Python, Node.js, and Rust nightly:

```bash
cd host/
make all       # install everything
make omz       # oh-my-zsh + plugins
make mold      # just the mold linker
make python    # latest Python via deadsnakes
make node      # latest Node.js via fnm
make rust      # Rust nightly + tools
make info      # print installed versions
```

## NanoClaw (OpenClaw AI Gateway)

Local AI assistant powered by [OpenClaw](https://github.com/openclaw/openclaw) (**latest stable: 2026.3.28**).

```bash
# Quick install
bash nanoclaw/setup-openclaw.sh

# With local Ollama inference
bash nanoclaw/setup-openclaw.sh --with-ollama

# Or just install the binary via Makefile
cd host/ && make nanoclaw
```

Runs as a systemd service on `http://127.0.0.1:18789/`. See `nanoclaw/README.md` for full docs.

## Databases

### Qdrant (Vector Database)

High-performance vector similarity search for embeddings and AI workloads.

```bash
# Install binary + start
bash qdrant/setup-qdrant.sh

# Or run via Docker
bash qdrant/setup-qdrant.sh --docker

# Status / stop
bash qdrant/setup-qdrant.sh --status
bash qdrant/setup-qdrant.sh --stop

# Install as systemd service
bash qdrant/setup-qdrant.sh --systemd
```

REST API at `http://127.0.0.1:6333`, gRPC at `127.0.0.1:6334`. Config tuned for on-disk storage to conserve RAM. See `qdrant/README.md`.

### SQLite (Relational Database)

Serverless, zero-config SQL database with WAL mode and optimized PRAGMAs.

```bash
# Install + create sample database
bash sqlite/setup-sqlite.sh

# Install only
bash sqlite/setup-sqlite.sh --install

# Backup a database
bash sqlite/setup-sqlite.sh --backup ~/.local/share/sqlite/databases/app.db

# Daily backup cron
bash sqlite/setup-sqlite.sh --cron
```

Databases stored in `~/.local/share/sqlite/databases/`. Runtime config (`.sqliterc`) enables WAL mode, foreign keys, and 256 MB mmap. See `sqlite/README.md`.

### Neo4j (Graph Database)

Native graph database with Cypher query language for relationship-heavy data.

```bash
# Install via APT
bash neo4j/setup-neo4j.sh

# Or run via Docker
bash neo4j/setup-neo4j.sh --docker

# Start / stop / status
bash neo4j/setup-neo4j.sh --start
bash neo4j/setup-neo4j.sh --stop
bash neo4j/setup-neo4j.sh --status

# Install APOC plugin
bash neo4j/setup-neo4j.sh --apoc
```

Browser UI at `http://127.0.0.1:7474`, Bolt at `bolt://127.0.0.1:7687`. Heap capped at 1 GB, page cache at 512 MB. See `neo4j/README.md`.

## mmWave Radar (RS-2944A)

Driver setup for the **D3 DesignCore RS-2944A** (TI AWR2944) 77 GHz mmWave radar sensor via the CP2105 USB-to-UART bridge.

```bash
# Full setup: kernel module, udev rules, dialout group, Python venv
bash mmwave/setup-mmwave.sh

# Check current driver state
bash mmwave/setup-mmwave.sh --check

# With ROS Melodic desktop-full (Docker) + ti_mmwave_rospkg
bash mmwave/setup-mmwave.sh --ros

# Custom Python venv path
bash mmwave/setup-mmwave.sh --venv ~/.venvs/myradar
```

This will:
1. Load the `cp210x` kernel module (Silicon Labs CP2105) and make it boot-persistent
2. Install udev rules creating stable symlinks: `/dev/radar_cfg` and `/dev/radar_data`
3. Add the user to the `dialout` group for serial port access
4. Create a Python venv with `pyserial`, `numpy`, `websockets`, `scipy`
5. (Optional) Build a Docker image with `ros-melodic-desktop-full` + [ti_mmwave_rospkg](https://github.com/radar-lab/ti_mmwave_rospkg)

> **Note:** ROS Melodic targets Ubuntu 18.04 (Bionic) and cannot be installed natively on
> Ubuntu 22.04. The `--ros` flag uses Docker with device passthrough for serial port access.

After setup, verify:
```bash
lsusb | grep "10c4"           # CP2105 detected
ls -la /dev/radar_*           # symlinks present
screen /dev/radar_cfg 115200  # CLI access (Ctrl+A K to exit)
```

See `mmwave/README.md` for detailed hardware info, troubleshooting, and TI references.

## PyTorch on Jetson

Standard PyPI wheels **do not** include CUDA support for aarch64. Use the included Jetson-specific installer:

```bash
bash pytorch/setup-pytorch-jetson.sh ~/.venvs/torch
```

This will:
1. Verify you're on a Jetson with CUDA
2. Install system dependencies
3. Create a virtual environment
4. Download PyTorch from NVIDIA's official Jetson wheels
5. Build TorchVision from source (required for CUDA on aarch64)
6. Run a verification test

After installation, verify:
```bash
source ~/.venvs/torch/bin/activate
python pytorch/torch-test.py
```

## Key Bindings (bspwm/sxhkd)

| Key                    | Action                   |
|------------------------|--------------------------|
| `super + Return`       | Terminal (alacritty)     |
| `super + d`            | App launcher (rofi)      |
| `super + h/j/k/l`     | Focus window             |
| `super + shift + h/j/k/l` | Swap window          |
| `super + {1-9}`        | Switch desktop           |
| `super + shift + {1-9}` | Move window to desktop |
| `super + f`            | Fullscreen               |
| `super + s`            | Floating                 |
| `super + w`            | Close window             |
| `super + alt + r`      | Restart bspwm            |
| `super + Escape`       | Reload sxhkd             |
| `Print`                | Screenshot (selection)   |

## Tmux

Prefix is **`Ctrl+a`**. Config lives in `tmux/tmux.conf` — symlink with `ln -sf ~/dotfiles/tmux/tmux.conf ~/.tmux.conf`.

| Key                    | Action                   |
|------------------------|--------------------------|
| `Ctrl+a`               | Prefix (instead of Ctrl+b) |
| `prefix + =`           | Vertical split           |
| `prefix + -`           | Horizontal split         |
| `prefix + h/j/k/l`    | Navigate panes (vim)     |
| `prefix + H/J/K/L`    | Resize panes             |
| `prefix + c`           | New window               |
| `prefix + Enter`       | Copy mode (vi keys)      |
| `prefix + r`           | Reload config            |

## Zsh

- **Framework**: [oh-my-zsh](https://ohmyz.sh/) (auto-installed by `install.sh` or `make omz`)
- **Prompt**: [Powerlevel10k](https://github.com/romkatv/powerlevel10k) — run `p10k configure`
- **Bundled plugins**: git, tmux, command-not-found, colored-man-pages, extract, z
- **Custom plugins**: zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions, fzf-tab
- **Smart cd**: [zoxide](https://github.com/ajeetdsouza/zoxide)
- **Essentials**: tmux, neovim, silversearcher-ag, tree, jq, stow
- **NVM**: lazy-loaded to keep shell startup fast

## Jetson-Specific Notes

- `OMP_NUM_THREADS` and `OPENBLAS_NUM_THREADS` set to 6 (matching core count)
- CUDA paths configured in `.zshenv`
- Picom (compositor) can be disabled in `bspwmrc` if GPU memory is tight
- `jtop` alias included for monitoring (`sudo pip install jetson-stats`)
- Cargo configured for 6 parallel compile jobs

### Switching to bspwm

```bash
bash scripts/select-bspwm.sh         # set as default + log out
bash scripts/select-bspwm.sh --now   # replace GNOME live (save work!)
bash scripts/select-bspwm.sh --revert  # switch back to GNOME
```

### Fix: Snap Browsers Broken (Firefox / Chromium)

Snap 2.70+ breaks all Snap apps on Jetson due to missing kernel config (`CONFIG_SQUASHFS_XATTR`).
Symptoms: `cannot set capabilities: Operation not permitted`, browsers won't launch.

```bash
# Automated fix — downgrades snapd to 2.68.5 and pins it
bash scripts/fix-snap-browsers.sh

# Check current status
bash scripts/fix-snap-browsers.sh --check

# Revert (unpin snapd)
bash scripts/fix-snap-browsers.sh --revert
```

See: [NVIDIA Forum — Chromium broken on Jetson](https://forums.developer.nvidia.com/t/338891)

---

## Windows / WSL2 Development Machine

A parallel set of configs for a **Windows + WSL2** workstation.

### Hardware (Windows Host)

| Spec       | Value                                    |
|------------|------------------------------------------|
| CPU        | AMD Ryzen 7 260 — 8 cores / 16 threads  |
| Memory     | 16 GB DDR5                               |
| GPU        | AMD Radeon 780M (iGPU)                   |
| OS         | Windows 11                               |
| Terminal   | WezTerm                                  |
| Theme      | Nordic Night (Nord on #121212)           |

### What's Included (Windows + WSL2)

```
windows/
├── scoop-essentials.ps1     # Scoop package manager + NerdFonts + tools
└── wezterm.lua              # WezTerm terminal (Nordic Night theme)
wsl/
├── .wslconfig               # WSL2 resource limits (10 GB / 12 cores)
├── install.sh               # Full WSL2 environment setup
├── zsh/
│   ├── .zshrc               # Zsh config (zinit, p10k, Nordic FZF)
│   └── .zshenv              # Environment variables (CUDA, .NET, Rust)
├── nvim/                    # LazyVim + Nordic Night
│   ├── init.lua
│   └── lua/
│       ├── config/
│       │   ├── lazy.lua     # LazyVim bootstrap + extras
│       │   ├── options.lua
│       │   ├── keymaps.lua
│       │   └── autocmds.lua
│       └── plugins/
│           ├── colorscheme.lua  # Nordic Night (AlexvZyl/nordic.nvim)
│           ├── lsp.lua          # LSPs: TS, Python, Rust, C++, C#, etc.
│           └── extras.lua       # GLSL, HLSL, WGSL, CUDA, ML plugins
└── tmux/
    └── tmux.conf            # Tmux with Nordic Night status bar
vscode/
├── extensions.json          # 50+ extensions (ML, shaders, CUDA, etc.)
└── install-extensions.ps1   # Auto-install script for VS Code/Windsurf
```

### Quick Start (Windows)

```powershell
# 1. Install Scoop essentials (includes WezTerm, NerdFonts, runtimes)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\windows\scoop-essentials.ps1

# 2. Install VS Code / Windsurf extensions
.\vscode\install-extensions.ps1
.\vscode\install-extensions.ps1 -Editor windsurf   # for Windsurf

# 3. Install WSL2 Ubuntu
wsl --install Ubuntu
```

### Quick Start (WSL2)

```bash
# Full setup: packages, zsh, neovim, rust, python, node, docker, CUDA
bash wsl/install.sh

# Or install specific modules
bash wsl/install.sh --packages   # apt packages only
bash wsl/install.sh --zsh        # zsh + zinit + p10k
bash wsl/install.sh --nvim       # LazyVim + Nordic Night
bash wsl/install.sh --rust       # Rust toolchain
bash wsl/install.sh --python     # Python + ruff + uv
bash wsl/install.sh --node       # Node.js via fnm
bash wsl/install.sh --docker     # Docker CE + NVIDIA Container Toolkit
bash wsl/install.sh --cuda       # CUDA toolkit + cuDNN + TensorRT
bash wsl/install.sh --dotnet     # .NET SDK (C#)
```

### Color Scheme: Nordic Night

Based on [Nordic Night](https://codeberg.org/ashton314/nordic-night) — the Nord palette on a darker `#121212` background for higher contrast. Applied consistently across:

- **WezTerm** — terminal colors, tab bar, cursor
- **Neovim** — via `AlexvZyl/nordic.nvim` with `#121212` overrides
- **Tmux** — status bar, pane borders, messages
- **Zsh/FZF** — selection colors, preview borders
- **VS Code** — via `arcticicestudio.nord-visual-studio-code`

### Fonts

Installed via Scoop (`scoop bucket add nerd-fonts`):

- **GeistMono Nerd Font** — primary (WezTerm, editor)
- **SauceCodePro Nerd Font** — fallback (SourceCodePro NerdFont)
- **Hack Nerd Font** — fallback

### LSP Servers (Neovim)

| Language   | Server                      |
|------------|-----------------------------|
| TypeScript | typescript-language-server   |
| Python     | pyright + ruff              |
| TailwindCSS| tailwindcss-language-server |
| Rust       | rust-analyzer (via rustup)  |
| C / C++    | clangd (with CUDA support)  |
| C#         | omnisharp                   |
| WGSL       | wgsl-analyzer               |
| Docker     | dockerfile-language-server  |
| Lua        | lua-language-server         |

### VS Code Extensions Coverage

- **Languages**: TypeScript, Python, Rust, C/C++, C#, TailwindCSS
- **ML/AI**: Jupyter, Data Wrangler, Python snippets
- **Shaders**: WGSL, HLSL, GLSL
- **GPU**: NVIDIA Nsight (CUDA)
- **DevOps**: Docker, Remote WSL, Remote Containers
- **Git**: GitLens, Git Graph

### WSL2 Performance Tuning

The `.wslconfig` allocates resources based on the Ryzen 7 260:

| Resource    | WSL2     | Windows  |
|-------------|----------|----------|
| RAM         | 10 GB    | ~6 GB    |
| CPU threads | 12       | 4        |
| Swap        | 4 GB     | —        |

Features: `autoMemoryReclaim=gradual`, `sparseVhd=true`, `nestedVirtualization=true`.

### CUDA on WSL2

> **Note:** The current system has an AMD Radeon 780M (iGPU). CUDA requires an NVIDIA GPU.
> The CUDA toolkit is included in the install script for when an NVIDIA GPU is added.
> Install the [NVIDIA WSL2 driver](https://developer.nvidia.com/cuda/wsl) on the Windows side.

## License

MIT
