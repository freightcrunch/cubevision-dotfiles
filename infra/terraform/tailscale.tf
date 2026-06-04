# ─── Tailscale Auth Key for automated node enrollment ────────────
resource "tailscale_tailnet_key" "build_server" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  description   = "${var.project_name}-build-server"
  tags          = ["tag:build-server"]
}

resource "tailscale_tailnet_key" "dev_vms" {
  reusable      = true
  ephemeral     = true
  preauthorized = true
  description   = "${var.project_name}-dev-vms"
  tags          = ["tag:dev-vm"]
}

# ─── Tailscale ACL (managed separately or via dashboard) ─────────
# This is informational — ACLs are typically managed in the Tailscale admin
# but can be imported via the tailscale_acl resource if needed.

# ─── DNS entries for local devices on tailnet ────────────────────
resource "tailscale_dns_nameservers" "local" {
  nameservers = [
    var.build_server.ip_address,
    "1.1.1.1",
    "8.8.8.8",
  ]
}
