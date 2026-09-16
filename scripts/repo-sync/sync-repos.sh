#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  Repo Sync — pull the latest freightcrunch repositories              ║
# ║                                                                      ║
# ║  Usage:  scripts/repo-sync/sync-repos.sh [DEST_DIR]                  ║
# ║                                                                      ║
# ║  Modes (SYNC_MODE):                                                  ║
# ║    mirror    (default) bare `git clone --mirror` + fetch --prune.    ║
# ║              Used by CI on the build server (DEST_DIR=/mirrors).     ║
# ║    worktree  regular clones; fast-forward the default branch.        ║
# ║              Skips repos with local changes or a non-default branch. ║
# ║                                                                      ║
# ║  Env (all optional):                                                 ║
# ║    GH_TOKEN      token with read access to the repos. Falls back to  ║
# ║                  your git credential helper / gh auth when unset.    ║
# ║    REPOS_FILE    repo list (default: scripts/repo-sync/repos.txt)    ║
# ║    SYNC_VERBOSE  1 = list new commit subjects. Keep this OFF in CI:  ║
# ║                  the dotfiles repo is public, so are its Actions     ║
# ║                  logs, and these repos are private.                  ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-${SYNC_DEST:-$HOME/src/freightcrunch}}"
SYNC_MODE="${SYNC_MODE:-mirror}"
REPOS_FILE="${REPOS_FILE:-$SCRIPT_DIR/repos.txt}"
SYNC_VERBOSE="${SYNC_VERBOSE:-0}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*" >&2; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; }

command -v git &>/dev/null || { error "git is required."; exit 1; }
case "$SYNC_MODE" in mirror|worktree) ;; *) error "SYNC_MODE must be mirror or worktree"; exit 1 ;; esac

# Authenticate per-command via an extra header, so the token never lands in
# .git/config or remote URLs (mirrors persist their remote URL).
git_auth() {
    if [ -n "${GH_TOKEN:-}" ]; then
        local basic
        basic="$(printf 'x-access-token:%s' "$GH_TOKEN" | base64 | tr -d '\n')"
        git -c "http.https://github.com/.extraheader=Authorization: basic $basic" "$@"
    else
        git "$@"
    fi
}

# rev-parse that prints nothing (instead of failing) for missing refs.
rev() { git -C "$1" rev-parse --verify --quiet "$2" 2>/dev/null || true; }

SUMMARY="| Repo | Branch | Before | After | New commits | Status |
|---|---|---|---|---|---|"
failures=0

# Appends a row to SUMMARY: repo branch before after status
record() {
    local repo="$1" branch="$2" before="$3" after="$4" status="$5" count="-"
    if [ -n "$before" ] && [ -n "$after" ] && [ -n "$6" ]; then
        count="$(git -C "$6" rev-list --count "$before..$after" 2>/dev/null || echo "?")"
    elif [ -z "$before" ] && [ -n "$after" ]; then
        count="(new clone)"
    fi
    SUMMARY+=$'\n'"| $repo | ${branch:--} | ${before:0:7} | ${after:0:7} | $count | $status |"
    if [ "$SYNC_VERBOSE" = "1" ] && [ -n "$before" ] && [ "$before" != "$after" ]; then
        git -C "$6" log --oneline "$before..$after" | sed 's/^/      /'
    fi
}

sync_mirror() {
    local repo="$1" dir="$DEST/${1#*/}.git" branch before after
    if [ -d "$dir" ]; then
        branch="$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || true)"
        before="$(rev "$dir" "refs/heads/$branch")"
        # Pick up default-branch renames upstream before fetching.
        git_auth -C "$dir" remote set-head origin --auto &>/dev/null || true
        git_auth -C "$dir" fetch --prune --quiet origin || return 1
    else
        git_auth clone --mirror --quiet "https://github.com/$repo.git" "$dir" || return 1
        branch="$(git -C "$dir" symbolic-ref --short HEAD)"
        before=""
    fi
    after="$(rev "$dir" "refs/heads/$branch")"
    record "$repo" "$branch" "$before" "$after" "ok" "$dir"
}

sync_worktree() {
    local repo="$1" dir="$DEST/${1#*/}" branch default before after
    if [ ! -d "$dir/.git" ]; then
        git_auth clone --quiet "https://github.com/$repo.git" "$dir" || return 1
        branch="$(git -C "$dir" branch --show-current)"
        record "$repo" "$branch" "" "$(rev "$dir" HEAD)" "ok" "$dir"
        return 0
    fi

    git_auth -C "$dir" fetch --prune --quiet origin || return 1
    default="$(git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    default="${default#origin/}"
    branch="$(git -C "$dir" branch --show-current)"
    before="$(rev "$dir" HEAD)"

    if [ -n "$(git -C "$dir" status --porcelain)" ]; then
        record "$repo" "$branch" "$before" "$before" "skipped: uncommitted changes" "$dir"
    elif [ -n "$default" ] && [ "$branch" != "$default" ]; then
        record "$repo" "$branch" "$before" "$before" "skipped: on '$branch', not '$default' (fetched only)" "$dir"
    elif ! git -C "$dir" merge --ff-only --quiet "origin/$branch" 2>/dev/null; then
        record "$repo" "$branch" "$before" "$before" "skipped: diverged from origin (fetched only)" "$dir"
    else
        after="$(rev "$dir" HEAD)"
        record "$repo" "$branch" "$before" "$after" "ok" "$dir"
    fi
}

mkdir -p "$DEST"
info "Syncing repos from $REPOS_FILE into $DEST (mode: $SYNC_MODE)"

while IFS= read -r line || [ -n "$line" ]; do
    repo="$(echo "${line%%#*}" | tr -d '[:space:]')"
    [ -z "$repo" ] && continue
    if ! "sync_$SYNC_MODE" "$repo"; then
        error "$repo: sync failed (check token access / network)"
        SUMMARY+=$'\n'"| $repo | - | - | - | - | **failed** |"
        failures=$((failures + 1))
    fi
done < "$REPOS_FILE"

echo
echo "$SUMMARY"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    { echo "### freightcrunch repo sync ($SYNC_MODE)"; echo; echo "$SUMMARY"; } >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$failures" -gt 0 ]; then
    error "$failures repo(s) failed to sync"
    exit 1
fi
info "All repos up to date"
