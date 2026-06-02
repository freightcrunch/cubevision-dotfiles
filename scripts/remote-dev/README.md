# Remote Development Stack

Encrypted remote virtualization over Tailscale with port forwarding and traffic inspection.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Bare Metal Host                                             │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  dev-vm-01  │  │  dev-vm-02  │  │  dev-vm-03  │  Incus │
│  │  tailscale  │  │  tailscale  │  │  tailscale  │  VMs   │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
│         │                │                │                 │
│         └────────────────┼────────────────┘                 │
│                          │                                  │
│              ┌───────────┴───────────┐                      │
│              │  Tailscale Subnet     │                      │
│              │  Router (host)        │                      │
│              └───────────┬───────────┘                      │
└──────────────────────────┼──────────────────────────────────┘
                           │ WireGuard (encrypted)
                           │
              ┌────────────┴────────────┐
              │     Tailscale Network    │
              └────────────┬────────────┘
                           │
┌──────────────────────────┼──────────────────────────────────┐
│ Developer Laptop                                            │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐      │
│  │ Windsurf │  │Wireshark │  │ tailscale serve/ssh  │      │
│  │ Remote   │  │(tailsc0) │  │ port forwards        │      │
│  └──────────┘  └──────────┘  └──────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Scripts

| Script | Layer | Purpose |
|--------|-------|---------|
| `01-hypervisor-incus.sh` | Hypervisor | Install & configure Incus on bare metal |
| `02-networking-tailscale.sh` | Networking | Join any machine to the tailnet |
| `03-port-forward.sh` | Port Forward | `tailscale serve`, SSH tunnels, multi-port |
| `04-traffic-inspect.sh` | Inspection | Wireshark/tshark captures, mitmproxy |
| `05-ide-remote.sh` | IDE Access | Prepare VM for Windsurf Remote SSH |

## Quick Start

### 1. Set up the host (bare metal server)

```bash
sudo bash 01-hypervisor-incus.sh
sudo bash 02-networking-tailscale.sh
sudo bash 02-networking-tailscale.sh subnet-router 10.100.0.0/24
```

### 2. Launch a dev VM

```bash
sudo bash 01-hypervisor-incus.sh launch dev-ubuntu images:ubuntu/24.04
incus exec dev-ubuntu -- bash
```

### 3. Inside the VM: join tailnet + prepare for IDE

```bash
sudo bash 02-networking-tailscale.sh
sudo bash 05-ide-remote.sh
```

### 4. From your laptop: connect

```bash
# Windsurf/VS Code: Remote-SSH → user@<tailscale-ip>
# Or SSH directly:
ssh user@dev-ubuntu  # Tailscale MagicDNS
```

### 5. Port forwarding

```bash
# Expose services on the tailnet
bash 03-port-forward.sh serve

# Ad-hoc SSH tunnel
bash 03-port-forward.sh ssh dev-ubuntu 8080 8080

# Multiple ports at once
bash 03-port-forward.sh multi dev-ubuntu 3000:3000 5432:5432 8080:8080
```

### 6. Traffic inspection

```bash
# Install tools
bash 04-traffic-inspect.sh install

# Capture decrypted tailnet traffic for 60s
bash 04-traffic-inspect.sh capture 60 "tcp port 8080"

# Live monitor HTTP requests
bash 04-traffic-inspect.sh live "http.request"

# HTTPS inspection with mitmproxy
bash 04-traffic-inspect.sh mitm
```

## Security Notes

- All inter-node traffic is WireGuard-encrypted (Tailscale)
- `tailscale serve` provides auto-TLS within the tailnet
- Tailscale SSH eliminates key management (uses tailnet identity)
- mitmproxy CA certs should never leave the inspection machine
- Auth keys for automated provisioning should be stored in a secret manager
- Ephemeral nodes auto-deregister when offline

## Requirements

- **Host**: Ubuntu 22.04+ / Debian 12+ with KVM support
- **Tailscale account**: Free tier supports up to 100 devices
- **Client**: Windsurf or VS Code with Remote-SSH extension
