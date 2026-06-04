# ─── General ──────────────────────────────────────────────────────
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "cubevision"
}

# ─── Build Server ─────────────────────────────────────────────────
variable "build_server" {
  description = "Build server configuration"
  type = object({
    host           = string
    user           = string
    ssh_key_path   = string
    ip_address     = string
    ssh_port       = number
  })
  default = {
    host         = "build-server"
    user         = "cube"
    ssh_key_path = "~/.ssh/id_ed25519"
    ip_address   = "192.168.1.100"
    ssh_port     = 22
  }
}

# ─── Local Network Devices ───────────────────────────────────────
variable "network_devices" {
  description = "Local network devices to monitor"
  type = map(object({
    ip       = string
    type     = string
    ssh_port = optional(number, 22)
    labels   = optional(map(string), {})
  }))
  default = {
    jetson-orin = {
      ip   = "192.168.1.10"
      type = "compute"
      labels = {
        arch = "aarch64"
        role = "edge-compute"
      }
    }
    radar-awr2944 = {
      ip   = "192.168.1.20"
      type = "sensor"
      labels = {
        device = "awr2944"
        role   = "radar"
      }
    }
    cam-front = {
      ip   = "192.168.1.30"
      type = "camera"
    }
    cam-rear = {
      ip   = "192.168.1.31"
      type = "camera"
    }
    threadripper = {
      ip   = "192.168.1.50"
      type = "workstation"
      labels = {
        arch = "x86_64"
        role = "ml-training"
      }
    }
  }
}

# ─── Cloudflare ───────────────────────────────────────────────────
variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone and Tunnel permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the domain"
  type        = string
}

variable "domain" {
  description = "Base domain for Cloudflare DNS records"
  type        = string
  default     = "cubevision.dev"
}

# ─── Tailscale ────────────────────────────────────────────────────
variable "tailscale_api_key" {
  description = "Tailscale API key"
  type        = string
  sensitive   = true
}

variable "tailscale_tailnet" {
  description = "Tailscale tailnet name (e.g., your-org.ts.net)"
  type        = string
}

# ─── K3s ──────────────────────────────────────────────────────────
variable "k3s_version" {
  description = "K3s version to install"
  type        = string
  default     = "v1.31.4+k3s1"
}

# ─── GitHub ───────────────────────────────────────────────────────
variable "github_token" {
  description = "GitHub PAT for Flux bootstrap and container registry"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_owner" {
  description = "GitHub owner/org for Flux"
  type        = string
  default     = "n-drw"
}

variable "github_repository" {
  description = "GitHub repository for Flux GitOps"
  type        = string
  default     = "cubevision-dotfiles"
}
