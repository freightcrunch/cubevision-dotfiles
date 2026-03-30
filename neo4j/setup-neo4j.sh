#!/usr/bin/env bash
# setup-neo4j.sh — Install and run Neo4j on Jetson Orin Nano
set -euo pipefail

NEO4J_VERSION="5.26.0"
NEO4J_DATA_DIR="$HOME/.local/share/neo4j"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEO4J_CONF_SRC="$SCRIPT_DIR/neo4j.conf"
DOCKER_IMAGE="neo4j:${NEO4J_VERSION}-community"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[neo4j]${NC} $*"; }
ok()    { echo -e "${GREEN}[neo4j]${NC} $*"; }
err()   { echo -e "${RED}[neo4j]${NC} $*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --docker       Run Neo4j via Docker
  --apt          Install Neo4j via official APT repository (default)
  --start        Start Neo4j service
  --stop         Stop Neo4j service
  --status       Show Neo4j status
  --systemd      Enable Neo4j systemd service
  --apoc         Install APOC plugin
  -h, --help     Show this help
EOF
}

ensure_dirs() {
    mkdir -p "$NEO4J_DATA_DIR"/{data,logs,import,plugins,conf}
    info "Data directory: $NEO4J_DATA_DIR"
}

check_java() {
    if ! command -v java &>/dev/null; then
        info "Java not found. Installing OpenJDK 17..."
        sudo apt-get update -qq
        sudo apt-get install -y openjdk-17-jre-headless
    fi
    local java_ver
    java_ver="$(java -version 2>&1 | head -1)"
    ok "Java: $java_ver"
}

install_apt() {
    info "Installing Neo4j Community Edition via APT..."

    check_java
    ensure_dirs

    # Add Neo4j GPG key and repository
    if [[ ! -f /usr/share/keyrings/neo4j-archive-keyring.gpg ]]; then
        info "Adding Neo4j APT repository..."
        curl -fsSL https://debian.neo4j.com/neotechnology.gpg.key \
            | sudo gpg --dearmor -o /usr/share/keyrings/neo4j-archive-keyring.gpg

        echo "deb [signed-by=/usr/share/keyrings/neo4j-archive-keyring.gpg] https://debian.neo4j.com stable latest" \
            | sudo tee /etc/apt/sources.list.d/neo4j.list > /dev/null
    fi

    sudo apt-get update -qq
    sudo apt-get install -y neo4j

    # Copy custom config
    if [[ -f "$NEO4J_CONF_SRC" ]]; then
        sudo cp "$NEO4J_CONF_SRC" /etc/neo4j/neo4j.conf
        ok "Custom config installed to /etc/neo4j/neo4j.conf"
    fi

    # Also keep a copy in user data dir
    cp "$NEO4J_CONF_SRC" "$NEO4J_DATA_DIR/conf/neo4j.conf"

    ok "Neo4j installed. Start with: sudo systemctl start neo4j"
    ok "Browser UI: http://127.0.0.1:7474"
    ok "Bolt:       bolt://127.0.0.1:7687"
}

run_docker() {
    info "Starting Neo4j ${NEO4J_VERSION} via Docker..."
    ensure_dirs

    docker run -d \
        --name neo4j \
        --restart unless-stopped \
        -p 7474:7474 \
        -p 7687:7687 \
        -e NEO4J_AUTH=neo4j/changeme \
        -e NEO4J_server_memory_heap_initial__size=512m \
        -e NEO4J_server_memory_heap_max__size=1g \
        -e NEO4J_server_memory_pagecache_size=512m \
        -v "$NEO4J_DATA_DIR/data:/data" \
        -v "$NEO4J_DATA_DIR/logs:/logs" \
        -v "$NEO4J_DATA_DIR/import:/var/lib/neo4j/import" \
        -v "$NEO4J_DATA_DIR/plugins:/plugins" \
        "$DOCKER_IMAGE"

    ok "Neo4j running at http://127.0.0.1:7474"
    ok "Default auth: neo4j / changeme"
}

start_neo4j() {
    if command -v neo4j &>/dev/null; then
        sudo systemctl start neo4j
        ok "Neo4j started (systemd)."
    elif docker ps -a -q -f name=neo4j | grep -q .; then
        docker start neo4j
        ok "Neo4j started (Docker)."
    else
        err "Neo4j not installed. Run: $0 --apt  or  $0 --docker"
        exit 1
    fi
}

stop_neo4j() {
    if sudo systemctl is-active neo4j &>/dev/null; then
        sudo systemctl stop neo4j
        ok "Neo4j stopped (systemd)."
    elif docker ps -q -f name=neo4j | grep -q .; then
        docker stop neo4j
        ok "Neo4j stopped (Docker)."
    else
        info "No running Neo4j instance found."
    fi
}

show_status() {
    echo "=== Neo4j Status ==="

    # APT/systemd
    if command -v neo4j &>/dev/null; then
        ok "Installed: $(neo4j --version 2>/dev/null || echo 'yes')"
        if sudo systemctl is-active neo4j &>/dev/null; then
            ok "Service: running (systemd)"
        else
            info "Service: stopped"
        fi
    else
        info "APT: not installed"
    fi

    # Docker
    if docker ps -q -f name=neo4j 2>/dev/null | grep -q .; then
        ok "Docker: running"
    elif docker ps -a -q -f name=neo4j 2>/dev/null | grep -q .; then
        info "Docker: stopped"
    else
        info "Docker: no container"
    fi

    # Health check
    if curl -sf http://127.0.0.1:7474 >/dev/null 2>&1; then
        ok "Browser UI: reachable"
    else
        info "Browser UI: unreachable"
    fi
}

enable_systemd() {
    sudo systemctl enable neo4j
    sudo systemctl start neo4j
    ok "Neo4j enabled and started via systemd."
}

install_apoc() {
    info "Installing APOC plugin..."
    local apoc_url="https://github.com/neo4j/apoc/releases/download/${NEO4J_VERSION}/apoc-${NEO4J_VERSION}-core.jar"

    if [[ -d /var/lib/neo4j/plugins ]]; then
        sudo curl -fSL "$apoc_url" -o /var/lib/neo4j/plugins/apoc-core.jar
        ok "APOC installed to /var/lib/neo4j/plugins/"
        info "Add to neo4j.conf: dbms.security.procedures.unrestricted=apoc.*"
        info "Restart Neo4j to activate."
    elif [[ -d "$NEO4J_DATA_DIR/plugins" ]]; then
        curl -fSL "$apoc_url" -o "$NEO4J_DATA_DIR/plugins/apoc-core.jar"
        ok "APOC installed to $NEO4J_DATA_DIR/plugins/ (Docker)"
        info "Restart the Neo4j container to activate."
    else
        err "No plugins directory found. Install Neo4j first."
        exit 1
    fi
}

# --- Main ---
if [[ $# -eq 0 ]]; then
    install_apt
    exit 0
fi

case "${1:-}" in
    --docker)      run_docker ;;
    --apt)         install_apt ;;
    --start)       start_neo4j ;;
    --stop)        stop_neo4j ;;
    --status)      show_status ;;
    --systemd)     enable_systemd ;;
    --apoc)        install_apoc ;;
    -h|--help)     usage ;;
    *)             err "Unknown option: $1"; usage; exit 1 ;;
esac
