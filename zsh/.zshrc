# ╔══════════════════════════════════════════════════════════════════════╗
# ║  .zshrc — Jetson Orin Nano  (Ubuntu 22.04 · aarch64)               ║
# ╚══════════════════════════════════════════════════════════════════════╝

# ─── Instant prompt (Powerlevel10k) ────────────────────────────────
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ─── Zinit plugin manager ──────────────────────────────────────────
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# ─── Plugins ───────────────────────────────────────────────────────
zinit ice depth=1; zinit light romkatv/powerlevel10k
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light Aloxaf/fzf-tab

# ─── Completion ────────────────────────────────────────────────────
autoload -Uz compinit && compinit -d "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"
zinit cdreplay -q

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# ─── History ───────────────────────────────────────────────────────
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory sharehistory
setopt hist_ignore_space hist_ignore_all_dups hist_save_no_dups hist_find_no_dups

# ─── Key bindings ──────────────────────────────────────────────────
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# ─── Aliases ───────────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lAh'
alias la='ls -A'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# python / venv
alias py='python3'
alias pip='python3 -m pip'
alias venv='python3 -m venv'
alias activate='source .venv/bin/activate'

# rust
alias cb='cargo build'
alias cr='cargo run'
alias ct='cargo test'
alias cc='cargo clippy'

# git
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline -20'
alias gd='git diff'

# jetson
alias jtop='sudo jtop'
alias tegrastats='sudo tegrastats'
alias jetson_clocks='sudo jetson_clocks'

# bspwm
alias brc='$EDITOR $XDG_CONFIG_HOME/bspwm/bspwmrc'
alias src='$EDITOR $XDG_CONFIG_HOME/sxhkd/sxhkdrc'

# ─── Tool integrations ────────────────────────────────────────────
# fzf
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh

# zoxide (smart cd) — unalias zi first to avoid conflict with zinit
unalias zi 2>/dev/null
command -v zoxide &>/dev/null && eval "$(zoxide init --cmd z zsh)"

# nvm (lazy-load to save ~200ms startup)
if [ -s "$NVM_DIR/nvm.sh" ]; then
    nvm() {
        unfunction nvm node npm npx 2>/dev/null
        source "$NVM_DIR/nvm.sh"
        source "$NVM_DIR/bash_completion" 2>/dev/null
        nvm "$@"
    }
    node() { nvm use default &>/dev/null; unfunction node; node "$@"; }
    npm()  { nvm use default &>/dev/null; unfunction npm;  npm "$@";  }
    npx()  { nvm use default &>/dev/null; unfunction npx;  npx "$@";  }
fi

# ─── Powerlevel10k config ─────────────────────────────────────────
[[ -f "$XDG_CONFIG_HOME/zsh/.p10k.zsh" ]] && source "$XDG_CONFIG_HOME/zsh/.p10k.zsh"

# ─── Local overrides ──────────────────────────────────────────────
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
