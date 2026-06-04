#!/usr/bin/env bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════════════╗
# ║  install-k3s.sh — Bootstrap K3s + Flux on the build server          ║
# ║                                                                      ║
# ║  Installs K3s (lightweight Kubernetes), Helm, Flux CLI, and          ║
# ║  bootstraps the GitOps pipeline from this repository.                ║
# ║                                                                      ║
# ║  Usage:                                                              ║
# ║    sudo bash infra/bootstrap/install-k3s.sh                          ║
# ║    sudo bash infra/bootstrap/install-k3s.sh --skip-flux              ║
# ╚══════════════════════════════════════════════════════════════════════╝

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; }
header(){ echo -e "\n${BLUE}══════════════════════════════════════════${NC}"; echo -e "${BLUE}  $*${NC}"; echo -e "${BLUE}══════════════════════════════════════════${NC}"; }

# --- Configuration ---
K3S_VERSION="v1.36.1+k3s1"
FLUX_VERSION="2.8.8"
HELM_VERSION="4.2.0"
KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"

# GitOps repo (this repo)
GITOPS_REPO="https://github.com/n-drw/cubevision-dotfiles.git"
GITOPS_BRANCH="main"
GITOPS_PATH="./infra/clusters/build-server"

SKIP_FLUX=false
[[ "${1:-}" == "--skip-flux" ]] && SKIP_FLUX=true

# --- Pre-flight ---
preflight() {
    header "Pre-flight checks"

    [[ $EUID -eq 0 ]] || { error "Must run as root"; exit 1; }

    # Check memory (minimum 4GB recommended)
    local mem_gb
    mem_gb=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
    if (( mem_gb < 4 )); then
        warn "Only ${mem_gb}GB RAM detected. K3s recommends 4GB+"
    fi

    # Check arch
    local arch
    arch=$(uname -m)
    info "Architecture: ${arch}"
    info "Memory: ${mem_gb}GB"
    info "OS: $(. /etc/os-release && echo "${PRETTY_NAME}")"
}

# --- Install K3s ---
install_k3s() {
    header "Installing K3s ${K3S_VERSION}"

    if command -v k3s &>/dev/null; then
        local current
        current=$(k3s --version | grep -oP 'v[\d.]+\+k3s\d')
        info "K3s already installed: ${current}"
        return 0
    fi

    curl -sfL https://get.k3s.io | \
        INSTALL_K3S_VERSION="${K3S_VERSION}" \
        INSTALL_K3S_EXEC="server" \
        sh -s - \
            --disable=traefik \
            --disable=servicelb \
            --write-kubeconfig-mode=644 \
            --tls-san="$(hostname)" \
            --tls-san="$(hostname -I | awk '{print $1}')" \
            --kubelet-arg="max-pods=250"

    # Wait for K3s to be ready
    info "Waiting for K3s to be ready..."
    local retries=30
    until kubectl get nodes --kubeconfig="${KUBECONFIG_PATH}" &>/dev/null; do
        ((retries--)) || { error "K3s failed to start"; exit 1; }
        sleep 2
    done

    info "K3s installed and running"
    kubectl get nodes --kubeconfig="${KUBECONFIG_PATH}"
}

# --- WSL2 workaround: strip Docker Desktop's malformed 9p mount ---
# Docker Desktop's WSL integration adds a /Docker/host 9p mount whose options
# contain an unescaped space ("C:\Program Files\..."), producing a /proc/mounts
# line with 7 fields instead of 6. The kubelet's system validation chokes on
# this and crash-loops with:
#   "system validation failed - wrong number of fields (expected 6, got 7)"
# Unmount it before k3s starts so the kubelet can parse /proc/mounts cleanly.
patch_k3s_wsl() {
    if ! grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
        return 0
    fi

    header "Applying WSL2 k3s workaround"

    local dropin_dir="/etc/systemd/system/k3s.service.d"
    local dropin="${dropin_dir}/wsl-umount.conf"

    mkdir -p "${dropin_dir}"
    cat > "${dropin}" <<'EOF'
# Added by install-k3s.sh for WSL2.
# Docker Desktop's /Docker/host 9p mount has an unescaped space in its options,
# breaking the kubelet's /proc/mounts parser. Unmount it before k3s starts.
# The leading '-' makes failure non-fatal (e.g. when the mount is absent).
[Service]
ExecStartPre=-/bin/umount /Docker/host
EOF

    systemctl daemon-reload

    # Apply immediately if k3s is up but unhealthy from the bad mount.
    if awk 'NF!=6' /proc/mounts | grep -q .; then
        warn "Detected malformed /proc/mounts entry; unmounting /Docker/host"
        umount /Docker/host 2>/dev/null || true
        systemctl restart k3s 2>/dev/null || true
    fi

    info "WSL2 workaround installed (${dropin})"
}

# --- Configure kubeconfig for non-root user ---
setup_kubeconfig() {
    header "Configuring kubeconfig"

    local target_user="${SUDO_USER:-}"
    if [[ -z "${target_user}" ]]; then
        warn "No SUDO_USER detected, skipping user kubeconfig setup"
        return 0
    fi

    local user_home
    user_home=$(eval echo "~${target_user}")
    local user_kube="${user_home}/.kube"

    mkdir -p "${user_kube}"
    cp "${KUBECONFIG_PATH}" "${user_kube}/config"
    chown -R "${target_user}:${target_user}" "${user_kube}"
    chmod 600 "${user_kube}/config"

    info "Kubeconfig written to ${user_kube}/config"
}

# --- Install Helm ---
install_helm() {
    header "Installing Helm ${HELM_VERSION}"

    if command -v helm &>/dev/null; then
        info "Helm already installed: $(helm version --short)"
        return 0
    fi

    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | \
        DESIRED_VERSION="${HELM_VERSION}" bash

    info "Helm installed: $(helm version --short)"
}

# --- Install Flux CLI ---
install_flux_cli() {
    header "Installing Flux CLI ${FLUX_VERSION}"

    if command -v flux &>/dev/null; then
        info "Flux already installed: $(flux --version)"
        return 0
    fi

    curl -fsSL https://fluxcd.io/install.sh | FLUX_VERSION="${FLUX_VERSION}" bash

    info "Flux installed: $(flux --version)"
}

# --- Bootstrap Flux GitOps ---
bootstrap_flux() {
    header "Bootstrapping Flux GitOps"

    export KUBECONFIG="${KUBECONFIG_PATH}"

    # Check Flux prerequisites
    flux check --pre || { error "Flux pre-checks failed"; exit 1; }

    # Check for GitHub token
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        warn "GITHUB_TOKEN not set."
        echo ""
        echo "To bootstrap Flux with write access (recommended):"
        echo "  export GITHUB_TOKEN=ghp_xxxxxxxxxxxx"
        echo "  flux bootstrap github \\"
        echo "    --owner=n-drw \\"
        echo "    --repository=cubevision-dotfiles \\"
        echo "    --branch=${GITOPS_BRANCH} \\"
        echo "    --path=${GITOPS_PATH} \\"
        echo "    --personal"
        echo ""
        echo "Or for read-only (no deploy keys, manual sync):"
        echo "  flux install"
        echo "  kubectl apply -f infra/clusters/build-server/flux-system/"
        echo ""

        # Install Flux components without bootstrap
        flux install
        info "Flux components installed (manual bootstrap required)"
        return 0
    fi

    flux bootstrap github \
        --owner=n-drw \
        --repository=cubevision-dotfiles \
        --branch="${GITOPS_BRANCH}" \
        --path="${GITOPS_PATH}" \
        --personal \
        --components-extra=image-reflector-controller,image-automation-controller

    info "Flux bootstrapped from ${GITOPS_REPO}"
}

# --- Install additional CLI tools ---
install_extras() {
    header "Installing extras (k9s, kustomize)"

    # k9s
    if ! command -v k9s &>/dev/null; then
        local arch_suffix="amd64"
        [[ "$(uname -m)" == "aarch64" ]] && arch_suffix="arm64"
        curl -fsSL "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_${arch_suffix}.tar.gz" | \
            tar xz -C /usr/local/bin k9s
        info "k9s installed"
    fi

    # kustomize
    if ! command -v kustomize &>/dev/null; then
        curl -fsSL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        mv kustomize /usr/local/bin/
        info "kustomize installed"
    fi
}

# --- Main ---
main() {
    preflight
    install_k3s
    patch_k3s_wsl
    setup_kubeconfig
    install_helm
    install_flux_cli
    install_extras

    if [[ "${SKIP_FLUX}" == "false" ]]; then
        bootstrap_flux
    else
        warn "Skipping Flux bootstrap (--skip-flux)"
    fi

    header "Build server bootstrap complete"
    echo ""
    echo "  K3s:    $(k3s --version | head -1)"
    echo "  Helm:   $(helm version --short)"
    echo "  Flux:   $(flux --version)"
    echo "  Config: ${KUBECONFIG_PATH}"
    echo ""
    echo "Next steps:"
    echo "  1. export KUBECONFIG=${KUBECONFIG_PATH}"
    echo "  2. kubectl get pods -A"
    echo "  3. flux get all"
    echo ""
}

main "$@"
