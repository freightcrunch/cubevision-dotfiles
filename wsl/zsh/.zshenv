# ─── XDG Base Directories ───────────────────────────────────────────
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# ─── Rust ───────────────────────────────────────────────────────────
export RUSTUP_HOME="$HOME/.rustup"
export CARGO_HOME="$HOME/.cargo"
[ -d "$CARGO_HOME/bin" ] && export PATH="$CARGO_HOME/bin:$PATH"

# sccache — shared compilation cache (speeds up rebuilds dramatically)
if command -v sccache &>/dev/null; then
    export RUSTC_WRAPPER="sccache"
fi

# ─── Python ─────────────────────────────────────────────────────────
export PYTHONDONTWRITEBYTECODE=1
export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"
export VIRTUAL_ENV_DISABLE_PROMPT=1

# ─── Node / JavaScript ─────────────────────────────────────────────
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node_repl_history"
export NVM_DIR="$HOME/.nvm"

# ─── fnm (Fast Node Manager) ───────────────────────────────────────
export FNM_DIR="$XDG_DATA_HOME/fnm"
[ -d "$FNM_DIR" ] && export PATH="$FNM_DIR:$PATH"

# ─── .NET / C# ─────────────────────────────────────────────────────
export DOTNET_ROOT="$HOME/.dotnet"
[ -d "$DOTNET_ROOT" ] && export PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# ─── CUDA (WSL2) ───────────────────────────────────────────────────
export CUDA_HOME="/usr/local/cuda"
if [ -d "$CUDA_HOME" ]; then
    export PATH="$CUDA_HOME/bin:$PATH"
    export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
fi

# WSL2 NVIDIA driver libs (mounted by Windows)
if [ -d "/usr/lib/wsl/lib" ]; then
    export LD_LIBRARY_PATH="/usr/lib/wsl/lib:${LD_LIBRARY_PATH:-}"
fi

# ─── Performance tuning (auto-detect: works on both Ryzen 7 & Threadripper)
_NCORES=$(nproc 2>/dev/null || echo 12)
_JOBS=$(( _NCORES > 4 ? _NCORES - 4 : _NCORES ))  # leave headroom
export OMP_NUM_THREADS=$_JOBS
export OPENBLAS_NUM_THREADS=$_JOBS
export MKL_NUM_THREADS=$_JOBS
export NUMEXPR_MAX_THREADS=$_JOBS
export CARGO_BUILD_JOBS=$_JOBS
export MAKEFLAGS="-j$_JOBS"
export CMAKE_BUILD_PARALLEL_LEVEL=$_JOBS
unset _NCORES _JOBS

# ─── General ────────────────────────────────────────────────────────
export EDITOR="nvim"
export VISUAL="$EDITOR"
export PAGER="less"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# ─── Local bin ──────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ─── Vulkan / GPU rendering ────────────────────────────────────────
export VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/nvidia_icd.json"

# ─── Cargo env (if present) ────────────────────────────────────────
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
