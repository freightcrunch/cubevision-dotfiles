#!/usr/bin/env bash
# setup-qdrant.sh — Install and run Qdrant on Jetson Orin Nano
set -euo pipefail

QDRANT_VERSION="v1.13.2"
QDRANT_DATA_DIR="$HOME/.local/share/qdrant"
QDRANT_CONFIG="$(cd "$(dirname "$0")" && pwd)/config.yaml"
QDRANT_BIN="$HOME/.local/bin/qdrant"
DOCKER_IMAGE="qdrant/qdrant:${QDRANT_VERSION}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[qdrant]${NC} $*"; }
ok()    { echo -e "${GREEN}[qdrant]${NC} $*"; }
err()   { echo -e "${RED}[qdrant]${NC} $*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --docker       Run Qdrant via Docker (NVIDIA runtime)
  --binary       Download and install the Qdrant binary (default)
  --start        Start Qdrant (binary mode)
  --stop         Stop running Qdrant instance
  --status       Show Qdrant service status
  --systemd      Install and enable systemd service
  -h, --help     Show this help
EOF
}

ensure_dirs() {
    mkdir -p "$QDRANT_DATA_DIR"/{storage,snapshots}
    mkdir -p "$HOME/.local/bin"
    info "Data directory: $QDRANT_DATA_DIR"
}

install_binary() {
    info "Installing Qdrant ${QDRANT_VERSION} (binary)..."
    ensure_dirs

    local arch
    arch="$(uname -m)"
    if [[ "$arch" == "aarch64" ]]; then
        arch="aarch64"
    elif [[ "$arch" == "x86_64" ]]; then
        arch="x86_64"
    else
        err "Unsupported architecture: $arch"
        exit 1
    fi

    local url="https://github.com/qdrant/qdrant/releases/download/${QDRANT_VERSION}/qdrant-${arch}-unknown-linux-gnu.tar.gz"
    local tmp
    tmp="$(mktemp -d)"

    info "Downloading from $url ..."
    curl -fSL "$url" -o "$tmp/qdrant.tar.gz"
    tar -xzf "$tmp/qdrant.tar.gz" -C "$tmp"
    mv "$tmp/qdrant" "$QDRANT_BIN"
    chmod +x "$QDRANT_BIN"
    rm -rf "$tmp"

    ok "Installed to $QDRANT_BIN"

    # Copy config
    cp "$QDRANT_CONFIG" "$QDRANT_DATA_DIR/config.yaml"
    # Patch storage path to absolute
    sed -i "s|storage_path: ./storage|storage_path: ${QDRANT_DATA_DIR}/storage|" "$QDRANT_DATA_DIR/config.yaml"
    sed -i "s|snapshots_path: ./snapshots|snapshots_path: ${QDRANT_DATA_DIR}/snapshots|" "$QDRANT_DATA_DIR/config.yaml"

    ok "Config copied to $QDRANT_DATA_DIR/config.yaml"
}

run_docker() {
    info "Starting Qdrant ${QDRANT_VERSION} via Docker..."
    ensure_dirs

    docker run -d \
        --name qdrant \
        --restart unless-stopped \
        --runtime nvidia \
        -p 6333:6333 \
        -p 6334:6334 \
        -v "$QDRANT_DATA_DIR/storage:/qdrant/storage" \
        -v "$QDRANT_DATA_DIR/snapshots:/qdrant/snapshots" \
        -v "$QDRANT_CONFIG:/qdrant/config/production.yaml" \
        "$DOCKER_IMAGE"

    ok "Qdrant running at http://127.0.0.1:6333"
    ok "Dashboard:       http://127.0.0.1:6333/dashboard"
}

start_binary() {
    if ! command -v "$QDRANT_BIN" &>/dev/null; then
        err "Qdrant binary not found. Run: $0 --binary"
        exit 1
    fi

    info "Starting Qdrant..."
    nohup "$QDRANT_BIN" --config-path "$QDRANT_DATA_DIR/config.yaml" \
        > "$QDRANT_DATA_DIR/qdrant.log" 2>&1 &
    echo "$!" > "$QDRANT_DATA_DIR/qdrant.pid"

    sleep 2
    if kill -0 "$(cat "$QDRANT_DATA_DIR/qdrant.pid")" 2>/dev/null; then
        ok "Qdrant running (PID $(cat "$QDRANT_DATA_DIR/qdrant.pid"))"
        ok "REST API: http://127.0.0.1:6333"
        ok "gRPC:     127.0.0.1:6334"
    else
        err "Failed to start. Check $QDRANT_DATA_DIR/qdrant.log"
        exit 1
    fi
}

stop_qdrant() {
    local pidfile="$QDRANT_DATA_DIR/qdrant.pid"
    if [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        kill "$(cat "$pidfile")"
        rm -f "$pidfile"
        ok "Qdrant stopped."
    else
        # Try docker
        if docker ps -q -f name=qdrant | grep -q .; then
            docker stop qdrant && docker rm qdrant
            ok "Qdrant (Docker) stopped."
        else
            info "No running Qdrant instance found."
        fi
    fi
}

show_status() {
    echo "=== Qdrant Status ==="
    local pidfile="$QDRANT_DATA_DIR/qdrant.pid"
    if [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        ok "Binary: running (PID $(cat "$pidfile"))"
    else
        info "Binary: not running"
    fi

    if docker ps -q -f name=qdrant 2>/dev/null | grep -q .; then
        ok "Docker: running"
    else
        info "Docker: not running"
    fi

    if curl -sf http://127.0.0.1:6333/healthz >/dev/null 2>&1; then
        ok "API: healthy"
    else
        info "API: unreachable"
    fi
}

install_systemd() {
    info "Installing systemd service..."
    sudo tee /etc/systemd/system/qdrant.service > /dev/null <<UNIT
[Unit]
Description=Qdrant Vector Database
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$QDRANT_BIN --config-path $QDRANT_DATA_DIR/config.yaml
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT
    sudo systemctl daemon-reload
    sudo systemctl enable --now qdrant.service
    ok "systemd service installed and started."
}

# --- Main ---
if [[ $# -eq 0 ]]; then
    install_binary
    start_binary
    exit 0
fi

case "${1:-}" in
    --docker)       run_docker ;;
    --binary)       install_binary ;;
    --start)        start_binary ;;
    --stop)         stop_qdrant ;;
    --status)       show_status ;;
    --systemd)      install_binary; install_systemd ;;
    -h|--help)      usage ;;
    *)              err "Unknown option: $1"; usage; exit 1 ;;
esac
