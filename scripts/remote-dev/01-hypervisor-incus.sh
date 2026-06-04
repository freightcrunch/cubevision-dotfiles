#!/usr/bin/env bash
set -euo pipefail

# Layer 1: Hypervisor — Incus (lightweight VMs + system containers)
# Run this on the bare-metal host that will run dev VMs.
# Requires: Ubuntu 22.04+ or Debian 12+

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || true

print_header() { echo -e "\n\033[1;34m==> $1\033[0m"; }
check_root() { [[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }; }

# --- Configuration ---
STORAGE_POOL="dev-pool"
STORAGE_DRIVER="btrfs"         # Options: zfs, btrfs, dir, lvm (btrfs works on WSL2; zfs module is absent there)
BRIDGE_NAME="incusbr0"
PROFILE_NAME="dev-vm"
VM_CPUS=4
VM_MEMORY="8GiB"
VM_DISK="50GiB"

install_incus() {
    print_header "Installing Incus"

    if command -v incus &>/dev/null; then
        echo "Incus already installed: $(incus --version)"
        return 0
    fi

    # Add the official Zabbly repository (maintains Incus packages)
    curl -fsSL https://pkgs.zabbly.com/key.asc | gpg --dearmor -o /etc/apt/keyrings/zabbly.gpg
    cat > /etc/apt/sources.list.d/zabbly-incus-stable.sources <<EOF
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/stable
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/zabbly.gpg
EOF

    apt-get update
    apt-get install -y incus incus-client

    # btrfs storage driver needs mkfs.btrfs to format the loop-backed pool
    if [[ "${STORAGE_DRIVER}" == "btrfs" ]]; then
        apt-get install -y btrfs-progs
    fi

    # Add current user to incus-admin group
    usermod -aG incus-admin "${SUDO_USER:-$USER}"

    echo "Incus installed: $(incus --version)"
}

initialize_incus() {
    print_header "Initializing Incus"

    # btrfs storage driver needs mkfs.btrfs to format the loop-backed pool
    if [[ "${STORAGE_DRIVER}" == "btrfs" ]] && ! command -v mkfs.btrfs &>/dev/null; then
        apt-get install -y btrfs-progs
    fi

    # Preseed configuration
    cat <<EOF | incus admin init --preseed
config: {}
networks:
  - config:
      ipv4.address: 10.100.0.1/24
      ipv4.nat: "true"
      ipv6.address: none
    description: "Dev bridge network"
    name: ${BRIDGE_NAME}
    type: bridge
storage_pools:
  - config:
      size: 100GiB
    description: "Dev storage pool"
    name: ${STORAGE_POOL}
    driver: ${STORAGE_DRIVER}
profiles:
  - name: default
    devices:
      root:
        path: /
        pool: ${STORAGE_POOL}
        type: disk
      eth0:
        name: eth0
        network: ${BRIDGE_NAME}
        type: nic
EOF

    echo "Incus initialized with pool=${STORAGE_POOL}, bridge=${BRIDGE_NAME}"
}

create_dev_profile() {
    print_header "Creating dev-vm profile"

    incus profile create "${PROFILE_NAME}" 2>/dev/null || true
    incus profile set "${PROFILE_NAME}" limits.cpu="${VM_CPUS}"
    incus profile set "${PROFILE_NAME}" limits.memory="${VM_MEMORY}"

    incus profile device add "${PROFILE_NAME}" root disk \
        path=/ pool="${STORAGE_POOL}" size="${VM_DISK}" 2>/dev/null || true
    incus profile device add "${PROFILE_NAME}" eth0 nic \
        name=eth0 network="${BRIDGE_NAME}" 2>/dev/null || true

    echo "Profile '${PROFILE_NAME}' created: ${VM_CPUS} CPUs, ${VM_MEMORY} RAM, ${VM_DISK} disk"
}

launch_dev_vm() {
    local vm_name="${1:-dev-ubuntu}"
    local image="${2:-images:ubuntu/24.04}"

    print_header "Launching VM: ${vm_name}"

    if incus info "${vm_name}" &>/dev/null; then
        echo "VM '${vm_name}' already exists"
        incus start "${vm_name}" 2>/dev/null || true
    else
        incus launch "${image}" "${vm_name}" --vm --profile default --profile "${PROFILE_NAME}"
        echo "Waiting for VM to boot..."
        sleep 15
        incus exec "${vm_name}" -- cloud-init status --wait 2>/dev/null || sleep 10
    fi

    echo "VM '${vm_name}' is running:"
    incus list "${vm_name}" -f compact
}

# --- Main ---
main() {
    check_root
    install_incus
    initialize_incus
    create_dev_profile

    echo ""
    print_header "Incus ready"
    echo "Launch a dev VM with:"
    echo "  incus launch images:ubuntu/24.04 dev-ubuntu --vm --profile default --profile ${PROFILE_NAME}"
    echo ""
    echo "Or run:"
    echo "  bash $0 launch <vm-name> [image]"
}

case "${1:-}" in
    launch) launch_dev_vm "${2:-}" "${3:-}" ;;
    *)      main ;;
esac
