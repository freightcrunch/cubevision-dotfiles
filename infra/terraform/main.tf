# ╔══════════════════════════════════════════════════════════════════════╗
# ║  OpenTofu / Terraform — Build Server Infrastructure                 ║
# ║                                                                      ║
# ║  Provisions: compute, networking, DNS, Cloudflare tunnel,            ║
# ║  and bootstraps Ansible for K3s + Flux.                              ║
# ║                                                                      ║
# ║  Usage:                                                              ║
# ║    tofu init                                                         ║
# ║    tofu plan -var-file=env/build-server.tfvars                       ║
# ║    tofu apply -var-file=env/build-server.tfvars                      ║
# ╚══════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.16"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  backend "local" {
    path = "state/terraform.tfstate"
  }
}

# ─── Providers ────────────────────────────────────────────────────
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "tailscale" {
  api_key = var.tailscale_api_key
  tailnet = var.tailscale_tailnet
}
