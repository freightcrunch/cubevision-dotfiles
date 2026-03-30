# ─── XDG Base Directories ───────────────────────────────────────────
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# ─── Rust ───────────────────────────────────────────────────────────
export RUSTUP_HOME="$HOME/.rustup"
export CARGO_HOME="$HOME/.cargo"
[ -d "$CARGO_HOME/bin" ] && export PATH="$CARGO_HOME/bin:$PATH"

# ─── Python ─────────────────────────────────────────────────────────
export PYTHONDONTWRITEBYTECODE=1
export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"
export VIRTUAL_ENV_DISABLE_PROMPT=1

# ─── Node / JavaScript ─────────────────────────────────────────────
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node_repl_history"
export NVM_DIR="$HOME/.nvm"

# ─── CUDA / Jetson Orin Nano ────────────────────────────────────────
export CUDA_HOME="/usr/local/cuda"
if [ -d "$CUDA_HOME" ]; then
    export PATH="$CUDA_HOME/bin:$PATH"
    export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
fi

# ─── Jetson-specific: limit OMP threads to physical cores ──────────
export OMP_NUM_THREADS=6
export OPENBLAS_NUM_THREADS=6

# ─── General ────────────────────────────────────────────────────────
export EDITOR="nvim"
export VISUAL="$EDITOR"
export PAGER="less"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# ─── Local bin ──────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"
. "$HOME/.cargo/env"
