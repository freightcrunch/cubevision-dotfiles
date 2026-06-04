# ─── Cloudflare Tunnel ────────────────────────────────────────────
resource "cloudflare_zero_trust_tunnel_cloudflared" "build_server" {
  account_id = var.cloudflare_account_id
  name       = "${var.project_name}-build-server"
  secret     = random_id.tunnel_secret.b64_std
}

resource "random_id" "tunnel_secret" {
  byte_length = 32
}

# ─── Tunnel DNS Records ──────────────────────────────────────────
resource "cloudflare_record" "grafana" {
  zone_id = var.cloudflare_zone_id
  name    = "build"
  type    = "CNAME"
  content = cloudflare_zero_trust_tunnel_cloudflared.build_server.cname
  proxied = true
  comment = "Grafana dashboard via Cloudflare Tunnel"
}

resource "cloudflare_record" "tekton" {
  zone_id = var.cloudflare_zone_id
  name    = "ci"
  type    = "CNAME"
  content = cloudflare_zero_trust_tunnel_cloudflared.build_server.cname
  proxied = true
  comment = "Tekton CI dashboard via Cloudflare Tunnel"
}

resource "cloudflare_record" "alerts" {
  zone_id = var.cloudflare_zone_id
  name    = "alerts"
  type    = "CNAME"
  content = cloudflare_zero_trust_tunnel_cloudflared.build_server.cname
  proxied = true
  comment = "Alertmanager via Cloudflare Tunnel"
}

# ─── Tunnel Ingress Config ───────────────────────────────────────
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "build_server" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.build_server.id

  config {
    ingress_rule {
      hostname = "build.${var.domain}"
      service  = "http://grafana.monitoring.svc:80"
    }
    ingress_rule {
      hostname = "ci.${var.domain}"
      service  = "http://tekton-dashboard.cicd.svc:9097"
    }
    ingress_rule {
      hostname = "alerts.${var.domain}"
      service  = "http://kube-prometheus-stack-alertmanager.monitoring.svc:9093"
    }
    # Catch-all
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# ─── Cloudflare Access (zero-trust auth) ─────────────────────────
resource "cloudflare_zero_trust_access_application" "build_dashboard" {
  zone_id          = var.cloudflare_zone_id
  name             = "Build Server Dashboard"
  domain           = "build.${var.domain}"
  session_duration = "24h"
  type             = "self_hosted"
}

resource "cloudflare_zero_trust_access_application" "ci_dashboard" {
  zone_id          = var.cloudflare_zone_id
  name             = "CI Dashboard"
  domain           = "ci.${var.domain}"
  session_duration = "24h"
  type             = "self_hosted"
}
