#!/usr/bin/env bash
set -euo pipefail

# Layer 3: Port Forwarding — tailscale serve + SSH tunnels
# Run this on the remote dev machine to expose services to your tailnet.

print_header() { echo -e "\n\033[1;34m==> $1\033[0m"; }

# --- Configuration ---
# Define services to expose via tailscale serve
declare -A SERVICES=(
    # [tailscale_port]="local_target"
    [443]="http://localhost:3000"       # Web app → HTTPS on tailnet
    [8443]="http://localhost:8080"      # API server
    [5173]="http://localhost:5173"      # Vite dev server
)

setup_tailscale_serve() {
    print_header "Configuring tailscale serve"

    # Reset existing serve config
    tailscale serve reset 2>/dev/null || true

    for ts_port in "${!SERVICES[@]}"; do
        local target="${SERVICES[$ts_port]}"
        echo "  Exposing ${target} → https://<tailnet-hostname>:${ts_port}"

        if [[ "${ts_port}" == "443" ]]; then
            tailscale serve --bg "${target}"
        else
            tailscale serve --bg --https="${ts_port}" "${target}"
        fi
    done

    echo ""
    tailscale serve status
}

setup_tailscale_funnel() {
    # Expose a service to the PUBLIC internet via Tailscale edge
    local port="${1:-443}"
    local target="${2:-http://localhost:3000}"

    print_header "Configuring tailscale funnel (public)"
    echo "WARNING: This exposes ${target} to the internet!"
    echo ""

    tailscale funnel --bg "${target}"
    tailscale funnel status
}

ssh_forward() {
    # Ad-hoc SSH port forwarding over Tailscale
    local remote_host="${1:-}"
    local local_port="${2:-8080}"
    local remote_port="${3:-8080}"

    if [[ -z "${remote_host}" ]]; then
        cat <<'EOF'
Usage: bash 03-port-forward.sh ssh <tailscale-hostname> [local_port] [remote_port]

Examples:
  # Forward remote:8080 to local:8080
  bash 03-port-forward.sh ssh dev-vm-01 8080 8080

  # Forward remote:5432 (postgres) to local:15432
  bash 03-port-forward.sh ssh dev-vm-01 15432 5432

  # Reverse: expose local:3000 on remote:3000
  bash 03-port-forward.sh ssh-reverse dev-vm-01 3000 3000
EOF
        return 1
    fi

    print_header "SSH tunnel: localhost:${local_port} → ${remote_host}:${remote_port}"
    echo "Press Ctrl+C to stop"
    ssh -N -L "${local_port}:localhost:${remote_port}" "${remote_host}"
}

ssh_reverse_forward() {
    # Reverse tunnel: expose local service on remote machine
    local remote_host="${1:-}"
    local remote_port="${2:-3000}"
    local local_port="${3:-3000}"

    if [[ -z "${remote_host}" ]]; then
        echo "Usage: bash 03-port-forward.sh ssh-reverse <tailscale-hostname> [remote_port] [local_port]"
        return 1
    fi

    print_header "Reverse SSH tunnel: ${remote_host}:${remote_port} → localhost:${local_port}"
    echo "Press Ctrl+C to stop"
    ssh -N -R "${remote_port}:localhost:${local_port}" "${remote_host}"
}

multi_forward() {
    # Forward multiple ports at once via SSH
    local remote_host="${1:-}"
    shift || true
    local port_pairs=("$@")

    if [[ -z "${remote_host}" || ${#port_pairs[@]} -eq 0 ]]; then
        cat <<'EOF'
Usage: bash 03-port-forward.sh multi <hostname> <local:remote> [local:remote] ...

Example:
  bash 03-port-forward.sh multi dev-vm-01 8080:8080 5432:5432 6379:6379
EOF
        return 1
    fi

    local ssh_args=(-N)
    for pair in "${port_pairs[@]}"; do
        local lport="${pair%%:*}"
        local rport="${pair##*:}"
        ssh_args+=(-L "${lport}:localhost:${rport}")
        echo "  localhost:${lport} → ${remote_host}:${rport}"
    done

    print_header "Multi-port SSH tunnel to ${remote_host}"
    echo "Press Ctrl+C to stop"
    ssh "${ssh_args[@]}" "${remote_host}"
}

show_status() {
    print_header "Tailscale serve status"
    tailscale serve status 2>/dev/null || echo "(no serve config)"

    echo ""
    print_header "Active SSH tunnels"
    ps aux | grep "ssh -N" | grep -v grep || echo "(none)"
}

# --- Main ---
case "${1:-}" in
    serve)       setup_tailscale_serve ;;
    funnel)      setup_tailscale_funnel "${2:-}" "${3:-}" ;;
    ssh)         shift; ssh_forward "$@" ;;
    ssh-reverse) shift; ssh_reverse_forward "$@" ;;
    multi)       shift; multi_forward "$@" ;;
    status)      show_status ;;
    *)
        cat <<'EOF'
Usage: bash 03-port-forward.sh <command> [args]

Commands:
  serve                        Configure tailscale serve for predefined services
  funnel [port] [target]       Expose a service publicly via Tailscale Funnel
  ssh <host> [lport] [rport]   SSH local port forward over Tailscale
  ssh-reverse <host> [rp] [lp] SSH reverse port forward
  multi <host> <l:r> [l:r]... Forward multiple ports at once
  status                       Show active forwards
EOF
        ;;
esac
