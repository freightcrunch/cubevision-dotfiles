#!/usr/bin/env bash
set -euo pipefail

# Layer 4: Traffic Inspection — Wireshark/tshark + mitmproxy on tailscale0
# Run this on the dev machine to capture and analyze tailnet traffic.

print_header() { echo -e "\n\033[1;34m==> $1\033[0m"; }

# --- Configuration ---
CAPTURE_DIR="${HOME}/captures"
TAILSCALE_IFACE="tailscale0"   # Linux default; macOS uses utun*
MITMPROXY_PORT=8888

install_tools() {
    print_header "Installing traffic inspection tools"

    local pkgs=()

    if ! command -v tshark &>/dev/null; then
        pkgs+=(tshark wireshark-common)
    fi
    if ! command -v mitmproxy &>/dev/null; then
        pkgs+=(mitmproxy)
    fi
    if ! command -v ngrep &>/dev/null; then
        pkgs+=(ngrep)
    fi
    if ! command -v tcpdump &>/dev/null; then
        pkgs+=(tcpdump)
    fi

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        sudo apt-get update
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
    fi

    # Allow non-root capture with tshark/dumpcap
    sudo setcap cap_net_raw,cap_net_admin=eip "$(which dumpcap)" 2>/dev/null || true

    mkdir -p "${CAPTURE_DIR}"
    echo "Tools ready. Captures saved to: ${CAPTURE_DIR}"
}

detect_tailscale_interface() {
    # Detect the correct interface name
    if ip link show tailscale0 &>/dev/null 2>&1; then
        TAILSCALE_IFACE="tailscale0"
    elif ip link show ts0 &>/dev/null 2>&1; then
        TAILSCALE_IFACE="ts0"
    else
        # macOS / fallback
        local iface
        iface=$(ip route get "$(tailscale ip -4)" 2>/dev/null | grep -oP 'dev \K\S+' || echo "tailscale0")
        TAILSCALE_IFACE="${iface}"
    fi
    echo "Tailscale interface: ${TAILSCALE_IFACE}"
}

capture_tailnet_plaintext() {
    # Capture decrypted traffic between tailnet nodes
    local duration="${1:-60}"
    local filter="${2:-}"
    local outfile="${CAPTURE_DIR}/tailnet-$(date +%Y%m%d-%H%M%S).pcapng"

    detect_tailscale_interface
    print_header "Capturing plaintext tailnet traffic on ${TAILSCALE_IFACE}"
    echo "Duration: ${duration}s | Filter: ${filter:-all} | Output: ${outfile}"
    echo "Press Ctrl+C to stop early"
    echo ""

    local args=(-i "${TAILSCALE_IFACE}" -w "${outfile}" -a "duration:${duration}")
    if [[ -n "${filter}" ]]; then
        args+=(-f "${filter}")
    fi

    tshark "${args[@]}"
    echo ""
    echo "Capture saved: ${outfile}"
    echo "Open with: wireshark ${outfile}"
}

capture_wireguard_encrypted() {
    # Capture encrypted WireGuard packets on the physical interface
    local iface="${1:-eth0}"
    local duration="${2:-60}"
    local outfile="${CAPTURE_DIR}/wireguard-${iface}-$(date +%Y%m%d-%H%M%S).pcapng"

    print_header "Capturing encrypted WireGuard traffic on ${iface}"
    echo "Duration: ${duration}s | Output: ${outfile}"
    echo ""

    tshark -i "${iface}" -w "${outfile}" -a "duration:${duration}" -f "udp port 41641"
    echo ""
    echo "Capture saved: ${outfile}"
}

live_monitor() {
    # Live traffic monitor on tailscale interface
    local filter="${1:-}"

    detect_tailscale_interface
    print_header "Live monitoring ${TAILSCALE_IFACE}"
    echo "Press Ctrl+C to stop"
    echo ""

    local args=(-i "${TAILSCALE_IFACE}" -l)
    if [[ -n "${filter}" ]]; then
        args+=(-Y "${filter}")
    fi

    tshark "${args[@]}"
}

start_mitmproxy() {
    # Run mitmproxy for HTTPS inspection
    local mode="${1:-regular}"

    print_header "Starting mitmproxy on port ${MITMPROXY_PORT}"

    case "${mode}" in
        transparent)
            echo "Mode: transparent proxy (requires iptables redirect)"
            echo ""
            echo "Add iptables rule on target machine:"
            echo "  iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-port ${MITMPROXY_PORT}"
            echo ""
            mitmproxy --mode transparent --listen-port "${MITMPROXY_PORT}"
            ;;
        reverse)
            local target="${2:-https://localhost:8080}"
            echo "Mode: reverse proxy → ${target}"
            mitmproxy --mode "reverse:${target}" --listen-port "${MITMPROXY_PORT}"
            ;;
        *)
            echo "Mode: regular forward proxy"
            echo "Configure clients with: http_proxy=http://$(tailscale ip -4):${MITMPROXY_PORT}"
            echo ""
            echo "Install CA cert on clients:"
            echo "  curl http://$(tailscale ip -4):${MITMPROXY_PORT}/cert/pem > ~/.mitmproxy-ca.pem"
            echo ""
            mitmproxy --listen-host "0.0.0.0" --listen-port "${MITMPROXY_PORT}"
            ;;
    esac
}

port_scan_tailnet() {
    # Quick port scan of a tailnet peer
    local target="${1:-}"

    if [[ -z "${target}" ]]; then
        echo "Usage: bash 04-traffic-inspect.sh scan <tailscale-ip-or-hostname>"
        return 1
    fi

    print_header "Scanning ${target} (common dev ports)"
    local ports="22,80,443,3000,3306,5173,5432,6379,8080,8443,9090"

    if command -v nmap &>/dev/null; then
        nmap -p "${ports}" "${target}" --open
    else
        # Fallback: bash /dev/tcp
        for port in ${ports//,/ }; do
            (echo >/dev/tcp/"${target}"/"${port}") 2>/dev/null && echo "  OPEN: ${target}:${port}" || true
        done
    fi
}

# --- Main ---
case "${1:-}" in
    install)     install_tools ;;
    capture)     shift; capture_tailnet_plaintext "$@" ;;
    wireguard)   shift; capture_wireguard_encrypted "$@" ;;
    live)        shift; live_monitor "$@" ;;
    mitm)        shift; start_mitmproxy "$@" ;;
    scan)        shift; port_scan_tailnet "$@" ;;
    *)
        cat <<'EOF'
Usage: bash 04-traffic-inspect.sh <command> [args]

Commands:
  install                      Install tshark, mitmproxy, ngrep, tcpdump
  capture [duration] [filter]  Capture decrypted tailnet traffic (pcapng)
  wireguard [iface] [duration] Capture encrypted WireGuard packets
  live [display-filter]        Live tshark monitor on tailscale0
  mitm [mode] [target]         Start mitmproxy (regular|transparent|reverse)
  scan <host>                  Port scan a tailnet peer

Examples:
  bash 04-traffic-inspect.sh capture 120 "tcp port 8080"
  bash 04-traffic-inspect.sh live "http.request"
  bash 04-traffic-inspect.sh mitm reverse https://api.example.com:8080
  bash 04-traffic-inspect.sh scan dev-vm-01
EOF
        ;;
esac
