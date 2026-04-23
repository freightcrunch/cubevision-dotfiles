# ╔══════════════════════════════════════════════════════════════════════╗
# ║  .zshrc — WSL2 (Ubuntu · x86_64)                                    ║
# ║  Nordic Night · LazyVim · Zinit                                      ║
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

# docker
alias dk='docker'
alias dkc='docker compose'
alias dkps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dkimg='docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"'

# nvim
alias v='nvim'
alias vi='nvim'
alias vim='nvim'

# WSL2
alias explorer='explorer.exe'
alias clip='clip.exe'
alias winhome='cd /mnt/c/Users/hi'

# ─── Nordic Night FZF colors ──────────────────────────────────────
export FZF_DEFAULT_OPTS="
  --color=bg+:#2E3440,bg:#121212,spinner:#81A1C1,hl:#BF616A
  --color=fg:#D8DEE9,header:#BF616A,info:#EBCB8B,pointer:#81A1C1
  --color=marker:#A3BE8C,fg+:#ECEFF4,prompt:#EBCB8B,hl+:#BF616A
  --border --height=40%
"

# ─── Tool integrations ──────────────────────────────────────────────
# fzf
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh

# zoxide (smart cd) — unalias zi first to avoid conflict with zinit
unalias zi 2>/dev/null
command -v zoxide &>/dev/null && eval "$(zoxide init --cmd z zsh)"

# fnm (Fast Node Manager)
if [ -d "$FNM_DIR" ] || command -v fnm &>/dev/null; then
    eval "$(fnm env --use-on-cd 2>/dev/null)"
fi

# ─── Powerlevel10k config ─────────────────────────────────────────
[[ -f "$XDG_CONFIG_HOME/zsh/.p10k.zsh" ]] && source "$XDG_CONFIG_HOME/zsh/.p10k.zsh"

# ─── Local overrides ──────────────────────────────────────────────
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
