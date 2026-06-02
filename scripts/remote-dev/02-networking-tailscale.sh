#!/usr/bin/env bash
set -euo pipefail

# Layer 2: Networking — Tailscale (mesh VPN for every node)
# Run this inside each VM/container/host that should join the tailnet.
# Requires: systemd-based Linux

print_header() { echo -e "\n\033[1;34m==> $1\033[0m"; }

# --- Configuration ---
TAILSCALE_ARGS=""
ADVERTISE_EXIT_NODE=false
ADVERTISE_ROUTES=""             # e.g., "10.100.0.0/24,192.168.1.0/24"
ENABLE_SSH=true
ACCEPT_DNS=true
HOSTNAME_OVERRIDE=""           # Leave empty to use system hostname

install_tailscale() {
    print_header "Installing Tailscale"

    if command -v tailscale &>/dev/null; then
        echo "Tailscale already installed: $(tailscale --version | head -1)"
        return 0
    fi

    curl -fsSL https://tailscale.com/install.sh | sh

    systemctl enable --now tailscaled
    echo "Tailscale installed: $(tailscale --version | head -1)"
}

configure_tailscale() {
    print_header "Configuring Tailscale"

    local args=()

    if [[ "${ENABLE_SSH}" == "true" ]]; then
        args+=(--ssh)
    fi

    if [[ "${ACCEPT_DNS}" == "true" ]]; then
        args+=(--accept-dns)
    fi

    if [[ "${ADVERTISE_EXIT_NODE}" == "true" ]]; then
        args+=(--advertise-exit-node)
        # Enable IP forwarding for exit node / subnet router
        echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-tailscale.conf
        echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf
        sysctl -p /etc/sysctl.d/99-tailscale.conf
    fi

    if [[ -n "${ADVERTISE_ROUTES}" ]]; then
        args+=(--advertise-routes="${ADVERTISE_ROUTES}")
        echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-tailscale.conf
        sysctl -p /etc/sysctl.d/99-tailscale.conf
    fi

    if [[ -n "${HOSTNAME_OVERRIDE}" ]]; then
        args+=(--hostname="${HOSTNAME_OVERRIDE}")
    fi

    echo "Running: tailscale up ${args[*]}"
    tailscale up "${args[@]}"
}

verify_connection() {
    print_header "Verifying Tailscale connection"

    echo "Status:"
    tailscale status

    echo ""
    echo "This node's IP:"
    tailscale ip -4

    echo ""
    echo "Tailnet name:"
    tailscale whois --self | grep -i "name" | head -1 || true
}

setup_as_subnet_router() {
    # Call this to configure as a subnet router for the Incus bridge network
    local subnet="${1:-10.100.0.0/24}"
    print_header "Configuring as subnet router for ${subnet}"

    echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-tailscale.conf
    echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf
    sysctl -p /etc/sysctl.d/99-tailscale.conf

    tailscale set --advertise-routes="${subnet}"
    echo ""
    echo "IMPORTANT: Approve this route in the Tailscale admin console:"
    echo "  https://login.tailscale.com/admin/machines"
    echo ""
    echo "Then on client machines, accept the route:"
    echo "  tailscale set --accept-routes"
}

generate_authkey_reminder() {
    print_header "Auth Key Setup (for automated VM provisioning)"
    cat <<'EOF'
For headless/automated VM enrollment, generate a reusable auth key:

  1. Go to: https://login.tailscale.com/admin/settings/keys
  2. Generate an auth key with:
     - Reusable: Yes
     - Ephemeral: Yes (nodes auto-removed when offline)
     - Tags: tag:dev-vm
  3. Use it:
     tailscale up --authkey=tskey-auth-XXXX --ssh --hostname=dev-vm-01

Store the key in a secret manager, never in source control.
EOF
}

# --- Main ---
main() {
    install_tailscale
    configure_tailscale
    verify_connection
    generate_authkey_reminder
}

case "${1:-}" in
    subnet-router) setup_as_subnet_router "${2:-}" ;;
    status)        tailscale status ;;
    *)             main ;;
esac
