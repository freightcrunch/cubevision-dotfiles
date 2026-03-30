#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  fix-snap-browsers.sh — Fix broken Snap apps on Jetson Orin          ║
# ║                                                                      ║
# ║  Snap 2.70+ breaks browsers (Firefox, Chromium) and other Snap apps  ║
# ║  on Jetson due to missing kernel config (CONFIG_SQUASHFS_XATTR).     ║
# ║  This script downgrades snapd to 2.68.5 and pins it.                ║
# ║                                                                      ║
# ║  Bug:  https://forums.developer.nvidia.com/t/338891                  ║
# ║  Info: https://jetsonhacks.com/2025/07/12/why-chromium-suddenly-     ║
# ║        broke-on-jetson-orin-and-how-to-bring-it-back/                ║
# ║                                                                      ║
# ║  Symptoms:                                                           ║
# ║    - "cannot set capabilities: Operation not permitted"              ║
# ║    - Snap apps launch from icon but nothing appears                  ║
# ║    - Firefox/Chromium refuse to start                                ║
# ║                                                                      ║
# ║  Usage:  bash scripts/fix-snap-browsers.sh                           ║
# ║          bash scripts/fix-snap-browsers.sh --check                   ║
# ║          bash scripts/fix-snap-browsers.sh --revert                  ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# Known-good snapd revision for Jetson (snapd 2.68.5)
SAFE_REVISION=24724
SAFE_VERSION="2.68.5"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; }

# ── Check current snapd status ────────────────────────────────────
check_status() {
    echo -e "\n${BLUE}━━━ Snap Status ━━━${NC}"

    if ! command -v snap &>/dev/null; then
        error "snap is not installed."
        exit 1
    fi

    local snap_ver
    snap_ver=$(snap version 2>/dev/null | grep "^snapd" | awk '{print $2}')
    echo "  snapd version: $snap_ver"

    # Check if held
    local held
    held=$(snap refresh --list 2>/dev/null | grep "held" || true)
    if snap list snapd 2>/dev/null | grep -q "held"; then
        info "snapd is pinned (held)"
    else
        # Alternative check
        local hold_status
        hold_status=$(sudo snap refresh --hold 2>&1 || true)
        if echo "$hold_status" | grep -qi "snapd.*held"; then
            info "snapd is pinned (held)"
        else
            warn "snapd is NOT pinned — it may auto-update to a broken version"
        fi
    fi

    # Quick test: try to detect the bug
    if [[ "$snap_ver" == "unavailable" ]]; then
        error "snapd appears broken or not running"
    elif [[ "$snap_ver" =~ ^2\.(7[0-9]|[8-9][0-9]) ]]; then
        error "snapd $snap_ver detected — this version breaks Snap apps on Jetson!"
        error "Run:  bash scripts/fix-snap-browsers.sh"
    else
        info "snapd $snap_ver — compatible with Jetson"
    fi

    # Test browser launch
    echo ""
    echo "  Installed snap apps:"
    snap list 2>/dev/null | head -15 || warn "Could not list snaps"
}

# ── Downgrade snapd ───────────────────────────────────────────────
fix_snapd() {
    echo -e "\n${BLUE}━━━ Fixing snapd for Jetson Orin ━━━${NC}"

    local current_ver
    current_ver=$(snap version 2>/dev/null | grep "^snapd" | awk '{print $2}')
    info "Current snapd: $current_ver"
    info "Target:        $SAFE_VERSION (revision $SAFE_REVISION)"

    # Check if already fixed
    if [[ "$current_ver" == "$SAFE_VERSION" ]]; then
        info "Already running snapd $SAFE_VERSION"
        # Still pin it to be safe
        sudo snap refresh --hold snapd 2>/dev/null || true
        info "Refresh hold confirmed."
        return 0
    fi

    # Create temp dir for download
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    info "Downloading snapd revision $SAFE_REVISION..."
    (cd "$tmpdir" && snap download snapd --revision="$SAFE_REVISION")

    info "Installing snapd $SAFE_VERSION..."
    sudo snap ack "$tmpdir/snapd_${SAFE_REVISION}.assert"
    sudo snap install "$tmpdir/snapd_${SAFE_REVISION}.snap"

    info "Pinning snapd to prevent auto-update..."
    sudo snap refresh --hold snapd

    # Verify
    local new_ver
    new_ver=$(snap version 2>/dev/null | grep "^snapd" | awk '{print $2}')
    info "snapd is now: $new_ver (held)"

    echo ""
    info "Fix applied. Try launching your browser:"
    info "  firefox &"
    info "  chromium &"
}

# ── Revert (unpin snapd, let it update) ──────────────────────────
revert() {
    echo -e "\n${BLUE}━━━ Reverting snapd pin ━━━${NC}"
    warn "This will unpin snapd and allow it to update."
    warn "Snap apps may break again if it updates past 2.70."
    echo ""
    read -rp "Continue? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Aborted."
        exit 0
    fi

    sudo snap refresh --unhold snapd
    info "snapd unpinned. It will update on next refresh cycle."
    warn "If browsers break, re-run: bash scripts/fix-snap-browsers.sh"
}

# ── Main ──────────────────────────────────────────────────────────
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  fix-snap-browsers — Jetson Orin Snap Fix                   ║"
    echo "║  Downgrades snapd to $SAFE_VERSION (rev $SAFE_REVISION) and pins it    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"

    case "${1:-}" in
        --check)
            check_status
            ;;
        --revert)
            revert
            ;;
        *)
            fix_snapd
            echo ""
            check_status
            ;;
    esac
}

main "$@"
