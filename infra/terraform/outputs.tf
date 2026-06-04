output "cloudflare_tunnel_id" {
  description = "Cloudflare Tunnel ID"
  value       = cloudflare_zero_trust_tunnel_cloudflared.build_server.id
}

output "cloudflare_tunnel_cname" {
  description = "Cloudflare Tunnel CNAME target"
  value       = cloudflare_zero_trust_tunnel_cloudflared.build_server.cname
}

output "tailscale_build_server_key" {
  description = "Tailscale auth key for build server"
  value       = tailscale_tailnet_key.build_server.key
  sensitive   = true
}

output "tailscale_vm_key" {
  description = "Tailscale auth key for dev VMs (ephemeral)"
  value       = tailscale_tailnet_key.dev_vms.key
  sensitive   = true
}

output "dashboard_urls" {
  description = "Dashboard URLs"
  value = {
    grafana      = "https://build.${var.domain}"
    tekton       = "https://ci.${var.domain}"
    alertmanager = "https://alerts.${var.domain}"
  }
}

output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory"
  value       = local_file.ansible_inventory.filename
}
