#!/usr/bin/env bash
set -euo pipefail

# Layer 5: IDE Access — Remote SSH dev environment over Tailscale
# Run this inside the remote VM to prepare it for Windsurf/VS Code Remote SSH.

print_header() { echo -e "\n\033[1;34m==> $1\033[0m"; }

# --- Configuration ---
DEV_USER="${1:-${SUDO_USER:-$USER}}"
WORKSPACE_DIR="/home/${DEV_USER}/workspace"
DOTFILES_REPO="https://github.com/n-drw/cubevision-dotfiles.git"

install_dev_essentials() {
    print_header "Installing development essentials"

    sudo apt-get update
    sudo apt-get install -y \
        build-essential \
        git \
        curl \
        wget \
        unzip \
        jq \
        ripgrep \
        fd-find \
        bat \
        htop \
        tree \
        tmux \
        zsh \
        python3 \
        python3-pip \
        python3-venv \
        nodejs \
        npm

    # Ensure SSH is running (Tailscale SSH may bypass this, but useful as fallback)
    sudo systemctl enable --now ssh 2>/dev/null || sudo systemctl enable --now sshd 2>/dev/null || true
}

configure_ssh_for_tailscale() {
    print_header "Configuring SSH for Tailscale"

    local sshd_config="/etc/ssh/sshd_config"

    # Tailscale SSH handles auth, but for standard SSH fallback:
    # Allow the Tailscale interface to accept connections
    if ! grep -q "# Tailscale config" "${sshd_config}"; then
        cat >> "${sshd_config}" <<'EOF'

# Tailscale config - accept connections from tailnet
AllowTcpForwarding yes
GatewayPorts no
PermitTunnel yes
EOF
        sudo systemctl reload sshd 2>/dev/null || sudo systemctl reload ssh 2>/dev/null || true
    fi

    echo "SSH configured for port forwarding over Tailscale"
}

setup_workspace() {
    print_header "Setting up workspace for ${DEV_USER}"

    sudo -u "${DEV_USER}" mkdir -p "${WORKSPACE_DIR}"

    # Clone dotfiles if not present
    if [[ ! -d "${WORKSPACE_DIR}/cubevision-dotfiles" ]]; then
        sudo -u "${DEV_USER}" git clone "${DOTFILES_REPO}" "${WORKSPACE_DIR}/cubevision-dotfiles" 2>/dev/null || \
            echo "Skipping dotfiles clone (set DOTFILES_REPO or clone manually)"
    fi

    echo "Workspace: ${WORKSPACE_DIR}"
}

setup_remote_ide_config() {
    print_header "Generating SSH config snippet for client"

    local ts_ip
    ts_ip="$(tailscale ip -4 2>/dev/null || echo '<tailscale-ip>')"
    local ts_hostname
    ts_hostname="$(tailscale whois --self 2>/dev/null | grep -oP 'Name:\s+\K\S+' || hostname)"

    cat <<EOF

# --- Add this to your LOCAL ~/.ssh/config ---
Host ${HOSTNAME:-dev-vm}
    HostName ${ts_ip}
    User ${DEV_USER}
    ForwardAgent yes
    # Port forwarding for common dev services
    LocalForward 3000 localhost:3000
    LocalForward 5173 localhost:5173
    LocalForward 8080 localhost:8080

# If using Tailscale SSH (no keys needed):
Host ${HOSTNAME:-dev-vm}-ts
    HostName ${ts_hostname}
    User ${DEV_USER}
    ForwardAgent yes
    ProxyCommand tailscale nc %h %p
# --- End snippet ---

EOF

    echo "In Windsurf/VS Code:"
    echo "  1. Install 'Remote - SSH' extension"
    echo "  2. Ctrl+Shift+P → 'Remote-SSH: Connect to Host'"
    echo "  3. Enter: ${DEV_USER}@${ts_ip}"
    echo ""
    echo "Or with Tailscale SSH (no keys):"
    echo "  ssh ${DEV_USER}@${ts_hostname}"
}

install_windsurf_server() {
    print_header "Pre-installing Windsurf/VS Code server components"

    # The IDE installs its server on first connect, but we can pre-warm it
    local vscode_dir="/home/${DEV_USER}/.vscode-server"

    sudo -u "${DEV_USER}" mkdir -p "${vscode_dir}"

    echo "Server directory prepared: ${vscode_dir}"
    echo "The IDE will auto-install its server binary on first Remote-SSH connection."
}

setup_docker() {
    print_header "Installing Docker (for dev containers)"

    if command -v docker &>/dev/null; then
        echo "Docker already installed"
    else
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker "${DEV_USER}"
    fi

    # Enable Docker socket for remote IDE dev containers
    sudo systemctl enable --now docker
    echo "Docker ready. User '${DEV_USER}' added to docker group."
}

# --- Main ---
main() {
    install_dev_essentials
    configure_ssh_for_tailscale
    setup_workspace
    install_windsurf_server
    setup_docker
    setup_remote_ide_config
}

case "${1:-}" in
    ssh-config) setup_remote_ide_config ;;
    docker)     setup_docker ;;
    *)          main ;;
esac
