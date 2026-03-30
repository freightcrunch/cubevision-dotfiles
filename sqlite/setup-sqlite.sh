#!/usr/bin/env bash
# setup-sqlite.sh — Install and configure SQLite on Jetson Orin Nano
set -euo pipefail

SQLITE_DATA_DIR="$HOME/.local/share/sqlite"
SQLITE_DB_DIR="$SQLITE_DATA_DIR/databases"
SQLITE_BACKUP_DIR="$SQLITE_DATA_DIR/backups"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQLITERC_SRC="$SCRIPT_DIR/sqliterc"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[sqlite]${NC} $*"; }
ok()    { echo -e "${GREEN}[sqlite]${NC} $*"; }
err()   { echo -e "${RED}[sqlite]${NC} $*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --install      Install SQLite and create directories (no sample DB)
  --status       Show SQLite version and directory info
  --backup DB    Backup a database file to the backups directory
  --cron         Install daily backup cron job
  -h, --help     Show this help

Default (no args): install + create sample database
EOF
}

ensure_dirs() {
    mkdir -p "$SQLITE_DB_DIR"
    mkdir -p "$SQLITE_BACKUP_DIR"
    info "Data directory: $SQLITE_DATA_DIR"
    info "DB directory:   $SQLITE_DB_DIR"
    info "Backup dir:     $SQLITE_BACKUP_DIR"
}

install_sqlite() {
    info "Installing SQLite3 and development libraries..."
    sudo apt-get update -qq
    sudo apt-get install -y sqlite3 libsqlite3-dev

    ensure_dirs

    # Symlink sqliterc
    if [[ -f "$SQLITERC_SRC" ]]; then
        ln -sf "$SQLITERC_SRC" "$HOME/.sqliterc"
        ok "Linked $SQLITERC_SRC -> ~/.sqliterc"
    fi

    # Copy config into data dir for reference
    cp "$SQLITERC_SRC" "$SQLITE_DATA_DIR/sqlite.conf"

    ok "SQLite $(sqlite3 --version | awk '{print $1}') installed."
}

create_sample_db() {
    local db="$SQLITE_DB_DIR/sample.db"
    info "Creating sample database: $db"

    sqlite3 "$db" <<'SQL'
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS metadata (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT OR REPLACE INTO metadata (key, value) VALUES
    ('version', '1.0.0'),
    ('created_by', 'setup-sqlite.sh'),
    ('platform', 'jetson-orin-nano');

CREATE TABLE IF NOT EXISTS notes (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    title      TEXT NOT NULL,
    content    TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_notes_created ON notes(created_at);

-- Trigger: auto-update updated_at
CREATE TRIGGER IF NOT EXISTS trg_notes_updated
AFTER UPDATE ON notes
BEGIN
    UPDATE notes SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;
SQL

    ok "Sample database created at $db"
}

backup_db() {
    local db="$1"
    if [[ ! -f "$db" ]]; then
        err "Database not found: $db"
        exit 1
    fi

    local basename
    basename="$(basename "$db" .db)"
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    local backup_file="$SQLITE_BACKUP_DIR/${basename}_${timestamp}.db"

    info "Backing up $db -> $backup_file"
    sqlite3 "$db" ".backup '$backup_file'"
    ok "Backup complete: $backup_file"

    # Keep only last 7 backups per database
    local count
    count=$(find "$SQLITE_BACKUP_DIR" -name "${basename}_*.db" | wc -l)
    if (( count > 7 )); then
        find "$SQLITE_BACKUP_DIR" -name "${basename}_*.db" -printf '%T@ %p\n' \
            | sort -n | head -n $(( count - 7 )) | awk '{print $2}' \
            | xargs rm -f
        info "Pruned old backups (kept 7)."
    fi
}

install_cron() {
    local cron_cmd="0 2 * * * find $SQLITE_DB_DIR -name '*.db' -exec bash $SCRIPT_DIR/setup-sqlite.sh --backup {} \\;"
    if crontab -l 2>/dev/null | grep -qF "setup-sqlite.sh"; then
        info "Cron job already installed."
    else
        (crontab -l 2>/dev/null; echo "$cron_cmd") | crontab -
        ok "Daily backup cron installed (2:00 AM)."
    fi
}

show_status() {
    echo "=== SQLite Status ==="
    if command -v sqlite3 &>/dev/null; then
        ok "Version: $(sqlite3 --version)"
    else
        err "sqlite3 not installed"
    fi

    if [[ -d "$SQLITE_DB_DIR" ]]; then
        local db_count
        db_count=$(find "$SQLITE_DB_DIR" -name '*.db' 2>/dev/null | wc -l)
        ok "Databases: $db_count in $SQLITE_DB_DIR"
    else
        info "Data directory not created yet"
    fi

    if [[ -f "$HOME/.sqliterc" ]]; then
        ok "Config: ~/.sqliterc linked"
    else
        info "Config: ~/.sqliterc not found"
    fi
}

# --- Main ---
if [[ $# -eq 0 ]]; then
    install_sqlite
    create_sample_db
    exit 0
fi

case "${1:-}" in
    --install)     install_sqlite ;;
    --status)      show_status ;;
    --backup)
        [[ -z "${2:-}" ]] && { err "Usage: $0 --backup <db-file>"; exit 1; }
        backup_db "$2"
        ;;
    --cron)        install_cron ;;
    -h|--help)     usage ;;
    *)             err "Unknown option: $1"; usage; exit 1 ;;
esac
