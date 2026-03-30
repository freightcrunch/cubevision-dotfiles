#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  select-bspwm.sh — Set bspwm as the default window manager          ║
# ║                                                                      ║
# ║  Works with GDM3 on Ubuntu 22.04 (Jetson Orin Nano).                ║
# ║                                                                      ║
# ║  Usage:                                                              ║
# ║    bash scripts/select-bspwm.sh            # set default + logout   ║
# ║    bash scripts/select-bspwm.sh --now      # replace WM live        ║
# ║    bash scripts/select-bspwm.sh --revert   # switch back to GNOME   ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; }

BSPWM_SESSION="bspwm"
GNOME_SESSION="ubuntu"
XSESSION_FILE="/usr/share/xsessions/bspwm.desktop"
ACCOUNTSSERVICE_DIR="/var/lib/AccountsService/users"
USER_ACCOUNTSSERVICE="$ACCOUNTSSERVICE_DIR/$USER"

# ── Preflight ──────────────────────────────────────────────────────
preflight() {
    if [ ! -f "$XSESSION_FILE" ]; then
        error "bspwm session file not found at $XSESSION_FILE"
        error "Install bspwm first:  sudo apt install bspwm"
        exit 1
    fi

    if ! command -v bspwm &>/dev/null; then
        error "bspwm is not installed."
        error "Install it:  sudo apt install bspwm sxhkd"
        exit 1
    fi

    if ! command -v sxhkd &>/dev/null; then
        warn "sxhkd not found — you won't have keybindings without it."
        warn "Install it:  sudo apt install sxhkd"
    fi

    info "bspwm found: $(command -v bspwm)"
}

# ── Set default session via AccountsService (GDM3) ────────────────
set_default_session() {
    local session="$1"
    echo -e "\n${BLUE}━━━ Setting default session: $session ━━━${NC}"

    # Method 1: AccountsService (used by GDM3)
    if [ -d "$ACCOUNTSSERVICE_DIR" ]; then
        if [ -f "$USER_ACCOUNTSSERVICE" ]; then
            # Update existing XSession line, or add it
            if grep -q "^XSession=" "$USER_ACCOUNTSSERVICE" 2>/dev/null; then
                sudo sed -i "s/^XSession=.*/XSession=$session/" "$USER_ACCOUNTSSERVICE"
            else
                echo "XSession=$session" | sudo tee -a "$USER_ACCOUNTSSERVICE" > /dev/null
            fi
        else
            sudo tee "$USER_ACCOUNTSSERVICE" > /dev/null <<EOF
[User]
XSession=$session
SystemAccount=false
EOF
        fi
        info "AccountsService updated: XSession=$session"
    fi

    # Method 2: ~/.dmrc (fallback for some display managers)
    cat > "$HOME/.dmrc" <<EOF
[Desktop]
Session=$session
EOF
    info "~/.dmrc updated: Session=$session"

    # Method 3: Ensure ~/.xsession exists for bspwm
    if [ "$session" = "$BSPWM_SESSION" ]; then
        cat > "$HOME/.xsession" <<'EOF'
#!/bin/sh
exec bspwm
EOF
        chmod +x "$HOME/.xsession"
        info "~/.xsession created"
    fi
}

# ── Replace current WM live ────────────────────────────────────────
switch_now() {
    echo -e "\n${BLUE}━━━ Switching to bspwm (live) ━━━${NC}"

    if [ "$XDG_SESSION_TYPE" != "x11" ]; then
        error "Live switch only works on X11 sessions."
        error "You're on: $XDG_SESSION_TYPE"
        error "Log out and select bspwm from GDM instead."
        exit 1
    fi

    local current_wm
    current_wm=$(wmctrl -m 2>/dev/null | grep "Name:" | awk '{print $2}' || echo "unknown")

    warn "Current WM: $current_wm"
    warn "This will kill your current window manager and start bspwm."
    warn "Make sure you have saved all work."
    echo ""
    read -rp "Continue? [y/N] " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        info "Aborted."
        exit 0
    fi

    # Kill current WM components
    pkill -x gnome-shell 2>/dev/null || true
    pkill -x mutter 2>/dev/null || true
    pkill -x metacity 2>/dev/null || true

    # Small delay for cleanup
    sleep 1

    # Start bspwm
    info "Starting bspwm..."
    exec bspwm
}

# ── Revert to GNOME ───────────────────────────────────────────────
revert() {
    set_default_session "$GNOME_SESSION"
    rm -f "$HOME/.xsession"
    info "Reverted to GNOME."
    echo ""
    warn "Log out and log back in to use GNOME."
    warn "Or reboot:  sudo reboot"
}

# ── Logout helper ─────────────────────────────────────────────────
prompt_logout() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  bspwm is set as your default session.                      ║"
    echo "║                                                              ║"
    echo "║  Log out and log back in to start bspwm.                    ║"
    echo "║  To revert:  bash scripts/select-bspwm.sh --revert          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    read -rp "Log out now? [y/N] " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        info "Logging out..."
        # Try multiple logout methods
        gnome-session-quit --logout --no-prompt 2>/dev/null \
            || loginctl terminate-user "$USER" 2>/dev/null \
            || { warn "Auto-logout failed. Please log out manually."; }
    else
        info "Log out manually when ready."
    fi
}

# ── Main ──────────────────────────────────────────────────────────
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  select-bspwm — Window Manager Switcher                     ║"
    echo "║  Jetson Orin Nano · GDM3 · Ubuntu 22.04                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    preflight

    case "${1:-}" in
        --now)
            set_default_session "$BSPWM_SESSION"
            switch_now
            ;;
        --revert)
            revert
            ;;
        *)
            set_default_session "$BSPWM_SESSION"
            prompt_logout
            ;;
    esac
}

main "$@"
