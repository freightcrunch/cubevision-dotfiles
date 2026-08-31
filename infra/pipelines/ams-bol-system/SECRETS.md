# ams-bol-system CI/CD — required secrets

These secrets are intentionally **not** committed to git. Create them once on the
build server (`export KUBECONFIG=/etc/rancher/k3s/k3s.yaml`).

## 1. Tekton deploy/ops secrets (namespace `cicd`)

### SSH key for the Azure VM (`ams-bol-ssh`)
Maps to the GH Actions `VM_SSH_KEY` secret. Must be the private key whose public
half is in `piersignal@<VM>:~/.ssh/authorized_keys`.

```bash
kubectl create secret generic ams-bol-ssh \
  --namespace=cicd \
  --type=kubernetes.io/ssh-auth \
  --from-file=ssh-privatekey=$HOME/.ssh/piersignal_vm
```

### App/deploy values (`ams-bol-secrets`)
Maps to the remaining GH Actions secrets.

**Already seeded** (live in the cluster): `vm-host` (172.171.2.196) and
`azure-storage-connection-string` (sourced from the shared `internationalpost`
Azure storage account, via the PayDuties `appsettings.json` `BlobConnection`).

**Still required** — add the remaining keys (merges into the existing secret):

```bash
kubectl patch secret ams-bol-secrets -n cicd --type=merge -p "$(cat <<EOF
{"stringData":{
  "internal-api-token":"$INTERNAL_API_TOKEN",
  "clerk-secret-key":"$CLERK_SECRET_KEY"
}}
EOF
)"

# binary/multiline values are easier via create+apply:
kubectl create secret generic ams-bol-secrets -n cicd \
  --from-literal=vm-host="172.171.2.196" \
  --from-literal=azure-storage-connection-string="$AZURE_STORAGE_CONNECTION_STRING" \
  --from-literal=internal-api-token="$INTERNAL_API_TOKEN" \
  --from-literal=clerk-secret-key="$CLERK_SECRET_KEY" \
  --from-file=cbp-private-key=/path/to/CBPAMSFOIA-JFSCHB \
  --from-file=vm-env-file=/path/to/vm.env \
  --dry-run=client -o yaml | kubectl apply -f -
```

Sources: `clerk-secret-key` → Clerk dashboard (piersignal.com, `sk_live_...`);
`internal-api-token` → backend `.env` on the VM (or rotate);
`cbp-private-key` → CBP SFTP key file; `vm-env-file` → full backend `.env`.

| Key | GH Actions equivalent |
|-----|-----------------------|
| `vm-host` | `secrets.VM_HOST` |
| `internal-api-token` | `secrets.INTERNAL_API_TOKEN` |
| `azure-storage-connection-string` | `secrets.AZURE_STORAGE_CONNECTION_STRING` |
| `clerk-secret-key` | `secrets.CLERK_SECRET_KEY` |
| `cbp-private-key` | `secrets.CBP_PRIVATE_KEY` |
| `vm-env-file` | `secrets.VM_ENV_FILE` |

> The deploy webhook also reuses the existing `github-webhook-secret` (cicd) and
> `tekton-triggers-sa` ServiceAccount created for the generic build pipeline.

## 2. Self-hosted runner (ARC) auth (namespace `arc-runners`)

Maps to GitHub repo runner registration. Classic PAT needs `repo` scope.

```bash
kubectl create secret generic arc-github-auth \
  --namespace=arc-runners \
  --from-literal=github_token=ghp_XXXXXXXX
```

(Or use a GitHub App: `github_app_id`, `github_app_installation_id`,
`github_app_private_key`.)

## Running things

- **Build + deploy (Tekton):** push to `master` triggers the `ams-bol-webhook`
  EventListener, or start manually from the Tekton Dashboard:
  *PipelineRuns → Create → `ams-bol-deploy`* (provide `source`, `cargo-cache`
  volumeClaim workspaces + `ssh-creds` secret workspace `ams-bol-ssh`).
- **Ops tasks (Tekton):** *TaskRuns → Create → pick `ams-*`* (e.g.
  `ams-build-indexes`, `ams-kill-stuck-queries`) and attach the `ssh-creds`
  workspace (`ams-bol-ssh`).
- **GitHub Actions (ARC):** the existing `.github/workflows` run on the
  self-hosted runners once `arc-github-auth` exists and the runner pods register.
