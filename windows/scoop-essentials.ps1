# ======================================================================
#   Scoop Essentials -- Windows Dev Machine
#   AMD Ryzen 7 260 - 16 GB - Radeon 780M
#
#   Usage (elevated PowerShell):
#     Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#     .\windows\scoop-essentials.ps1
# ======================================================================

$ErrorActionPreference = "Stop"

function Write-Step { param([string]$msg) Write-Host "[+] $msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Skip { param([string]$msg) Write-Host "[!] $msg" -ForegroundColor Yellow }

# ─── Install Scoop if missing ────────────────────────────────────────
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Step "Installing Scoop..."
    irm get.scoop.sh | iex
} else {
    Write-Skip "Scoop already installed"
}

# ─── Add buckets ─────────────────────────────────────────────────────
Write-Step "Adding Scoop buckets..."
$buckets = @("extras", "versions", "nerd-fonts", "java")
foreach ($bucket in $buckets) {
    scoop bucket add $bucket 2>$null
}
Write-Ok "Buckets configured"

# ─── Core CLI tools ──────────────────────────────────────────────────
Write-Step "Installing core CLI tools..."
$core = @(
    "git",
    "curl",
    "wget",
    "7zip",
    "ripgrep",
    "fd",
    "bat",
    "fzf",
    "jq",
    "yq",
    "delta",        # better git diffs
    "less",
    "tree",
    "unzip",
    "gzip",
    "zoxide",       # smart cd
    "starship",     # cross-shell prompt
    "coreutils",
    "pipx",         # isolated Python CLI apps
    "fastfetch"     # system info (neofetch replacement)
)
foreach ($pkg in $core) {
    if (-not (scoop which $pkg 2>$null)) {
        scoop install $pkg
    }
}
Write-Ok "Core CLI tools installed"

# ─── Terminal & Editor ───────────────────────────────────────────────
Write-Step "Installing terminal and editors..."
$editors = @(
    "wezterm",
    "neovim",
    "vscode",       # or 'vscodium' for FOSS build
    "komorebi",     # tiling window manager
    "whkd"          # hotkey daemon for komorebi
)
foreach ($pkg in $editors) {
    if (-not (scoop which $pkg 2>$null)) {
        scoop install $pkg
    }
}
Write-Ok "Terminal, editors & WM installed (komorebi, whkd)"

# ─── NerdFonts ───────────────────────────────────────────────────────
Write-Step "Installing NerdFonts (requires admin for font registration)..."
$fonts = @(
    "SauceCodePro-NF",   # SourceCodePro NerdFont
    "GeistMono-NF",      # Geist Mono NerdFont
    "Hack-NF"            # Hack NerdFont
)
foreach ($font in $fonts) {
    if (-not (scoop list $font 2>$null | Select-String $font)) {
        scoop install $font
    }
}
Write-Ok "NerdFonts installed (SauceCodePro, GeistMono, Hack)"

# ─── Language Runtimes ───────────────────────────────────────────────
Write-Step "Installing language runtimes..."

# Node.js (LTS)
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    scoop install nodejs-lts
}

# Python
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    scoop install python
}

# Rust (stable + nightly)
if (-not (Get-Command rustup -ErrorAction SilentlyContinue)) {
    scoop install rustup
    rustup default stable
    rustup toolchain install nightly
    rustup component add clippy rustfmt rust-analyzer rust-src llvm-tools
    rustup component add --toolchain nightly clippy rustfmt rust-analyzer rust-src llvm-tools
    rustup target add wasm32-unknown-unknown
    rustup target add --toolchain nightly wasm32-unknown-unknown
}

# .NET SDK (for C# development)
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    scoop install dotnet-sdk
}

# Go (for TUI installer and general dev)
if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    scoop install go
}

Write-Ok "Language runtimes installed"

# ─── Dev Tools ───────────────────────────────────────────────────────
Write-Step "Installing development tools..."
$devtools = @(
    "cmake",
    "ninja",
    "llvm",
    "make",
    "docker",       # Docker CLI (Docker Desktop installed separately)
    "kubectl",
    "lazygit",
    "lazydocker",
    "gh",           # GitHub CLI
    "binaryen",     # wasm-opt
    "perl",         # needed for openssl-sys builds
    "sccache",      # shared compilation cache
    "mkcert",       # local HTTPS certs
    "ngrok"         # tunneling
)
foreach ($pkg in $devtools) {
    if (-not (scoop which $pkg 2>$null)) {
        scoop install $pkg
    }
}
Write-Ok "Dev tools installed"

# ─── Python global tools ─────────────────────────────────────────────
Write-Step "Installing Python global tools..."
try { python -m pip install --user ruff uv 2>$null } catch { Write-Skip "pip not available yet -- run 'python -m pip install ruff uv' manually" }
try { pipx ensurepath 2>$null } catch {}
Write-Ok "Python tools installed (ruff, uv, pipx)"

# ─── Node.js global tools ────────────────────────────────────────────
Write-Step "Installing Node.js global tools..."
try { npm install -g pnpm typescript ts-node prettier eslint wrangler 2>$null } catch { Write-Skip "npm not available yet -- restart shell then run 'npm install -g pnpm typescript prettier eslint wrangler'" }
Write-Ok "Node.js tools installed (pnpm, typescript, prettier, eslint, wrangler)"

# ─── Cargo tools ─────────────────────────────────────────────────────
Write-Step "Installing Cargo tools..."
try {
    cargo install --locked cargo-watch cargo-expand cargo-nextest cargo-leptos wasm-bindgen-cli 2>$null
    cargo install --locked wasmtime-cli 2>$null
    cargo install --locked sccache 2>$null
} catch { Write-Skip "cargo not available yet -- restart shell then run the cargo install commands manually" }
Write-Ok "Cargo tools installed (cargo-leptos, wasm-bindgen, wasmtime, sccache)"

# ─── Streaming / Media ───────────────────────────────────────────────
Write-Step "Installing streaming and media tools..."
$media = @(
    "ffmpeg",
    "obs-studio",
    "vlc",
    "imagemagick",
    "yt-dlp"
)
foreach ($pkg in $media) {
    if (-not (scoop which $pkg 2>$null)) {
        scoop install $pkg
    }
}
Write-Ok "Streaming & media tools installed (ffmpeg, OBS, VLC, ImageMagick, yt-dlp)"

# ─── Cloud CLIs ─────────────────────────────────────────────────────
Write-Step "Installing cloud CLIs..."
$cloud = @(
    "azure-cli",        # Azure
    "aws"               # AWS CLI v2
    # wrangler installed via npm (see Node.js global tools)
)
foreach ($pkg in $cloud) {
    if (-not (scoop which $pkg 2>$null)) {
        scoop install $pkg
    }
}
Write-Ok "Cloud CLIs installed (Azure, AWS, Cloudflare Workers)"

# ─── Database Tools ─────────────────────────────────────────────────
Write-Step "Installing database tools..."
$databases = @(
    "postgresql",       # PostgreSQL client + server
    "sqlite",           # SQLite CLI
    "go-sqlcmd"         # SQL Server CLI (mssql-tools)
)
foreach ($pkg in $databases) {
    if (-not (scoop which $pkg 2>$null)) {
        scoop install $pkg
    }
}
# DBeaver as a universal DB GUI
if (-not (scoop which dbeaver 2>$null)) {
    scoop install dbeaver
}
Write-Ok "Database tools installed (PostgreSQL, SQLite, sqlcmd, DBeaver)"

# ─── 3D / Point Cloud / Rendering ──────────────────────────────────
Write-Step "Installing 3D and point cloud tools..."
$viz3d = @(
    "blender",          # 3D modeling & rendering
    "cloudcompare",     # point cloud viewer / editor
    "meshlab"           # mesh processing
)
foreach ($pkg in $viz3d) {
    if (-not (scoop which $pkg 2>$null)) {
        scoop install $pkg
    }
}
Write-Ok "3D tools installed (Blender, CloudCompare, MeshLab)"

# ─── ML / AI ───────────────────────────────────────────────────────
Write-Step "Installing ML and AI tools..."
if (-not (scoop which ollama 2>$null)) {
    scoop install ollama
}
Write-Ok "ML tools installed (Ollama)"

# ─── IaC / Kubernetes ──────────────────────────────────────────────
Write-Step "Installing IaC and Kubernetes tools..."
$iac = @(
    "terraform",
    "helm",
    "k9s"               # Kubernetes TUI
)
foreach ($pkg in $iac) {
    if (-not (scoop which $pkg 2>$null)) {
        scoop install $pkg
    }
}
Write-Ok "IaC & K8s tools installed (Terraform, Helm, k9s)"

# ─── API / Networking ──────────────────────────────────────────────
Write-Step "Installing API and networking tools..."
$nettools = @(
    "bruno",            # API testing (open-source Postman alternative)
    "wireshark"         # network analysis
)
foreach ($pkg in $nettools) {
    if (-not (scoop which $pkg 2>$null)) {
        scoop install $pkg
    }
}
Write-Ok "API & networking tools installed (Bruno, Wireshark)"

# ─── Windows Power Tools ───────────────────────────────────────────
Write-Step "Installing Windows power tools..."
$powertools = @(
    "powertoys",        # Microsoft PowerToys
    "sysinternals"      # Process Explorer, Autoruns, etc.
)
foreach ($pkg in $powertools) {
    if (-not (scoop which $pkg 2>$null)) {
        scoop install $pkg
    }
}
Write-Ok "Power tools installed (PowerToys, Sysinternals)"

# ─── Python ML / Point Cloud packages ──────────────────────────────
Write-Step "Installing Python ML & point cloud packages..."
try {
    python -m pip install --user jupyter open3d laspy pyntcloud trimesh 2>$null
    python -m pip install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124 2>$null
    python -m pip install --user transformers accelerate datasets peft trl bitsandbytes 2>$null
} catch {
    Write-Skip "pip ML packages not installed yet -- run manually after restart"
}
Write-Ok "Python ML & point cloud packages installed"

# ─── WezTerm config ──────────────────────────────────────────────────
Write-Step "Linking WezTerm config..."
$weztermConfigDir = "$env:USERPROFILE\.config\wezterm"
if (-not (Test-Path $weztermConfigDir)) {
    New-Item -ItemType Directory -Path $weztermConfigDir -Force | Out-Null
}
$dotfilesDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$weztermSrc = Join-Path $dotfilesDir "windows\wezterm.lua"
$weztermDst = Join-Path $weztermConfigDir "wezterm.lua"
if (Test-Path $weztermSrc) {
    Copy-Item -Path $weztermSrc -Destination $weztermDst -Force
    Write-Ok "WezTerm config linked to $weztermDst"
} else {
    Write-Skip "wezterm.lua not found at $weztermSrc"
}

# ─── Komorebi config ────────────────────────────────────────────────
Write-Step "Linking Komorebi configs..."
$komorebiSrc = Join-Path $dotfilesDir "windows\komorebi.json"
$komorebiDst = "$env:USERPROFILE\komorebi.json"
if (Test-Path $komorebiSrc) {
    Copy-Item -Path $komorebiSrc -Destination $komorebiDst -Force
    Write-Ok "komorebi.json installed to $komorebiDst"
} else {
    Write-Skip "komorebi.json not found at $komorebiSrc"
}

$komorebiBarSrc = Join-Path $dotfilesDir "windows\komorebi.bar.json"
$komorebiBarDst = "$env:USERPROFILE\komorebi.bar.json"
if (Test-Path $komorebiBarSrc) {
    Copy-Item -Path $komorebiBarSrc -Destination $komorebiBarDst -Force
    Write-Ok "komorebi.bar.json installed to $komorebiBarDst"
} else {
    Write-Skip "komorebi.bar.json not found at $komorebiBarSrc"
}

# ─── whkdrc ─────────────────────────────────────────────────────────
Write-Step "Linking whkdrc..."
$whkdConfigDir = "$env:USERPROFILE\.config"
if (-not (Test-Path $whkdConfigDir)) {
    New-Item -ItemType Directory -Path $whkdConfigDir -Force | Out-Null
}
$whkdSrc = Join-Path $dotfilesDir "windows\.config\whkdrc"
$whkdDst = Join-Path $whkdConfigDir "whkdrc"
if (Test-Path $whkdSrc) {
    Copy-Item -Path $whkdSrc -Destination $whkdDst -Force
    Write-Ok "whkdrc installed to $whkdDst"
} else {
    Write-Skip "whkdrc not found at $whkdSrc"
}

# ─── .wslconfig ──────────────────────────────────────────────────────
Write-Step "Copying .wslconfig..."
$wslconfigSrc = Join-Path $dotfilesDir "wsl\.wslconfig"
$wslconfigDst = "$env:USERPROFILE\.wslconfig"
if (Test-Path $wslconfigSrc) {
    Copy-Item -Path $wslconfigSrc -Destination $wslconfigDst -Force
    Write-Ok ".wslconfig installed to $wslconfigDst"
} else {
    Write-Skip ".wslconfig not found at $wslconfigSrc"
}

# ─── Summary ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "" 
Write-Host "=============================================================" -ForegroundColor Blue
Write-Host "  Scoop essentials installed!" -ForegroundColor Green
Write-Host "" 
Write-Host "  Next steps:" -ForegroundColor Blue
Write-Host "  1. Install Docker Desktop from docker.com" -ForegroundColor Blue
Write-Host "  2. Enable WSL2 integration in Docker Desktop settings" -ForegroundColor Blue
Write-Host "  3. Run: wsl --install Ubuntu" -ForegroundColor Blue
Write-Host "  4. Inside WSL2, run: bash wsl/install.sh" -ForegroundColor Blue
Write-Host "  5. Restart WezTerm to apply config + fonts" -ForegroundColor Blue
Write-Host "  6. Run: komorebic start --whkd" -ForegroundColor Blue
Write-Host "  7. For Threadripper: copy wsl\.wslconfig.threadripper" -ForegroundColor Blue
Write-Host "=============================================================" -ForegroundColor Blue
