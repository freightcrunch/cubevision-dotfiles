# Build Server Infrastructure

GitOps-managed Kubernetes cluster for CI/CD, monitoring, and secure remote access to the local device network.

## Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │              Tailscale Mesh                  │
                    └──────┬──────────────┬───────────────┬───────┘
                           │              │               │
┌──────────────────────────┼──────────────┼───────────────┼──────────────────────┐
│ Build Server (K3s)       │              │               │                      │
│                          │              │               │                      │
│  ┌─────────────────┐  ┌─┴────────┐  ┌──┴─────────┐  ┌─┴──────────────┐       │
│  │ Flux GitOps     │  │Cloudflare│  │ OpenVPN-AS │  │ Tekton CI/CD   │       │
│  │ (this repo)     │  │ Tunnel   │  │ (LAN VPN)  │  │ Pipelines      │       │
│  └────────┬────────┘  └──────────┘  └────────────┘  └───────┬────────┘       │
│           │                                                   │                │
│  ┌────────┴─────────────────────────────────────────────┐     │                │
│  │ Prometheus Stack                                     │     │                │
│  │  ├─ Prometheus (metrics collection, 30d retention)   │     │                │
│  │  ├─ Grafana (dashboards)                             │     │                │
│  │  ├─ Alertmanager (notifications)                     │     │                │
│  │  ├─ Node Exporter                                    │     │                │
│  │  └─ Blackbox Exporter (ICMP/TCP/HTTP probes)         │     │                │
│  └──────────────────────────────────────────────────────┘     │                │
│           │                                                   │                │
│  ┌────────┴──────────┐  ┌────────────────────────────────┐    │                │
│  │ Network Health    │  │ chatcli-operator               │    │                │
│  │ Monitor           │  │ (custom K8s operator)          │    │                │
│  │  ├─ Jetson Orin   │  └────────────────────────────────┘    │                │
│  │  ├─ AWR2944 Radar │                                        │                │
│  │  ├─ Cameras       │  ┌────────────────────────────────┐    │                │
│  │  └─ Threadripper  │  │ Flux Image Automation          │◄───┘                │
│  └───────────────────┘  │ (auto-deploy on image push)    │                     │
│                          └────────────────────────────────┘                     │
└────────────────────────────────────────────────────────────────────────────────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
   ┌──────┴──────┐  ┌─────┴─────┐  ┌──────┴──────┐
   │ Jetson Orin │  │AWR2944    │  │ Cameras     │
   │ (compute)   │  │(radar)    │  │ (sensors)   │
   └─────────────┘  └───────────┘  └─────────────┘
```

## Directory Structure

```
infra/
├── bootstrap/
│   └── install-k3s.sh              # One-shot: install K3s + Helm + Flux
├── clusters/
│   └── build-server/
│       ├── flux-system/            # Flux bootstrap (auto-managed)
│       ├── kustomization.yaml      # Root: wires sources → infra → apps
│       ├── sources.yaml            # Kustomization: Helm repos
│       ├── infrastructure.yaml     # Kustomization: core services
│       ├── apps.yaml               # Kustomization: workloads
│       └── tekton.yaml             # Kustomization: Tekton CI/CD
├── helm/
│   ├── sources/                    # HelmRepository definitions
│   │   ├── helm-prometheus-community.yaml
│   │   ├── helm-cloudflare.yaml
│   │   ├── helm-openvpn.yaml
│   │   ├── helm-grafana.yaml
│   │   └── helm-bitnami.yaml
│   ├── infrastructure/             # HelmRelease definitions (core)
│   │   ├── namespaces.yaml
│   │   ├── prometheus-stack.yaml
│   │   ├── cloudflared.yaml
│   │   └── openvpn-as.yaml
│   ├── apps/                       # HelmRelease definitions (workloads)
│   │   ├── chatcli-operator.yaml
│   │   ├── network-health-monitor.yaml
│   │   └── flux-image-automation.yaml
│   └── tekton/                     # Tekton CI/CD (vendored upstream manifests)
│       ├── pipelines.yaml          # Pipelines v1.13.1
│       ├── triggers.yaml           # Triggers v0.36.0
│       ├── triggers-interceptors.yaml
│       └── dashboard.yaml          # Dashboard v0.69.0
├── pipelines/
│   └── build-and-push.yaml         # Tekton Pipeline + Triggers
└── README.md
```

## Quick Start

### 1. Bootstrap the cluster

```bash
# On the build server (bare metal or VM)
sudo bash infra/bootstrap/install-k3s.sh
```

### 2. Create required secrets

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# GitHub Container Registry credentials
kubectl create secret docker-registry ghcr-credentials \
  --namespace=cicd \
  --docker-server=ghcr.io \
  --docker-username=n-drw \
  --docker-password=ghp_XXXXXX

# Cloudflare tunnel credentials (dashboard-managed "cubework" tunnel)
# Get the connector token from the Zero Trust dashboard
# (Networks > Tunnels > cubework > Configure) or via the CLI:
TOKEN=$(cloudflared tunnel token cubework)
kubectl create secret generic cloudflared-credentials \
  --namespace=networking \
  --from-literal=tunnel-token="$TOKEN"

# OpenVPN admin password
kubectl create secret generic openvpn-admin \
  --namespace=networking \
  --from-literal=username=admin \
  --from-literal=password=$(openssl rand -base64 24)

# GitHub webhook secret (for CI triggers)
kubectl create secret generic github-webhook-secret \
  --namespace=cicd \
  --from-literal=token=$(openssl rand -hex 20)

# Grafana admin password
kubectl create secret generic grafana-admin \
  --namespace=monitoring \
  --from-literal=admin-password=$(openssl rand -base64 24)
```

### 3. Bootstrap Flux

```bash
export GITHUB_TOKEN=ghp_XXXXXX
flux bootstrap github \
  --owner=n-drw \
  --repository=cubevision-dotfiles \
  --branch=main \
  --path=./infra/clusters/build-server \
  --personal \
  --components-extra=image-reflector-controller,image-automation-controller
```

### 4. Verify

```bash
flux get all
kubectl get pods -A
kubectl get helmreleases -A
```

## Accessing Services

| Service | Access Method |
|---------|--------------|
| Grafana | `tailscale serve` or `build.cubevision.dev` (Cloudflare tunnel) |
| Tekton Dashboard | `ci.cubevision.dev` or `kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097` |
| Prometheus | `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090` |
| OpenVPN | UDP 1194 / TCP 443 on build server IP |
| Alertmanager | `kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093` |

## Network Devices

Configure device hostnames in `/etc/hosts` or local DNS:

```
192.168.1.10  jetson-orin.local
192.168.1.20  radar.local
192.168.1.30  cam-front.local
192.168.1.31  cam-rear.local
192.168.1.50  threadripper.local
```

## CI/CD Flow

```
Push to main → GitHub Webhook → Tekton EventListener
  → git-clone → run-tests → kaniko build+push
  → Flux Image Automation detects new tag
  → Flux updates HelmRelease → auto-deploy
```

## Monitoring

- **ICMP probes**: Ping all devices every 30s
- **TCP probes**: Check SSH, Ollama, K8s API ports
- **HTTP probes**: Health endpoints on Jetson, Threadripper
- **Alerts**: Slack/Discord/email via Alertmanager (configure in `prometheus-stack.yaml`)
