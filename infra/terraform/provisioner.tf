# ─── Generate Ansible inventory from Terraform state ─────────────
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory/hosts.yml"
  content  = yamlencode({
    all = {
      vars = {
        ansible_user            = var.build_server.user
        ansible_ssh_private_key_file = var.build_server.ssh_key_path
        k3s_version             = var.k3s_version
        tailscale_auth_key      = tailscale_tailnet_key.build_server.key
        tailscale_vm_auth_key   = tailscale_tailnet_key.dev_vms.key
        cloudflare_tunnel_token = cloudflare_zero_trust_tunnel_cloudflared.build_server.tunnel_token
        github_token            = var.github_token
        github_owner            = var.github_owner
        github_repository       = var.github_repository
        domain                  = var.domain
      }
      children = {
        build_servers = {
          hosts = {
            (var.build_server.host) = {
              ansible_host = var.build_server.ip_address
              ansible_port = var.build_server.ssh_port
            }
          }
        }
        network_devices = {
          hosts = {
            for name, dev in var.network_devices : name => {
              ansible_host = dev.ip
              device_type  = dev.type
              device_labels = dev.labels
            }
          }
        }
      }
    }
  })

  file_permission = "0600"
}

# ─── Generate Ansible vars from tunnel credentials ───────────────
resource "local_file" "tunnel_credentials" {
  filename        = "${path.module}/../ansible/roles/cloudflared/files/tunnel-credentials.json"
  content         = jsonencode({
    AccountTag   = var.cloudflare_account_id
    TunnelSecret = random_id.tunnel_secret.b64_std
    TunnelID     = cloudflare_zero_trust_tunnel_cloudflared.build_server.id
  })
  file_permission = "0600"
}

# ─── Run Ansible after infrastructure is provisioned ─────────────
resource "null_resource" "run_ansible" {
  depends_on = [
    local_file.ansible_inventory,
    local_file.tunnel_credentials,
  ]

  triggers = {
    inventory_hash = local_file.ansible_inventory.content_md5
    always_run     = timestamp()
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../ansible"
    command     = <<-EOT
      ansible-playbook \
        -i inventory/hosts.yml \
        site.yml \
        --diff \
        -e "env=${var.environment}"
    EOT
  }
}
