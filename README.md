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
 │   editor ........... neovim (lazyvim)                                                           │
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
├── nvim/                 # Neovim config (LazyVim)
│   ├── init.lua
│   ├── lazyvim.json
│   ├── stylua.toml
│   └── lua/
│       ├── config/
│       │   ├── autocmds.lua
│       │   ├── keymaps.lua
│       │   ├── lazy.lua
│       │   └── options.lua
│       └── plugins/
│           └── colorscheme.lua
├── ranger/               # Ranger file manager config
│   ├── rc.conf
│   ├── rifle.conf
│   └── scope.sh
├── pytorch/              # PyTorch/TorchVision Jetson installer
│   ├── setup-pytorch-jetson.sh
│   └── torch-test.py
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
./scripts/install.sh --nvim      # neovim (LazyVim)
./scripts/install.sh --js        # nvm, npm, eslint, prettier
./scripts/install.sh --pytorch   # prints PyTorch install instructions
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

## License

MIT
