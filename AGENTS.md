# AGENTS.md

Guidance for coding agents (Claude Code, Codex, Hermes/OpenClaw via NemoClaw, etc.) working in
`cubevision-dotfiles`. Human-oriented docs live in `README.md` and each directory's `README.md`.

## What this repo is

Dotfiles and infrastructure for the cubevision fleet:

| Path | What | Runs on |
|---|---|---|
| `scripts/install.sh`, `host/Makefile`, `zsh/`, `tmux/`, `bspwm/`, … | Workstation / Jetson setup | Jetson Orin Nano (aarch64, JetPack), Linux hosts |
| `wsl/`, `windows/`, `vscode/` | Windows 11 + WSL2 dev setup | Threadripper workstation |
| `nemoclaw/` | NVIDIA NemoClaw (OpenClaw/Hermes) + local llama.cpp (TurboQuant) with whichllm model ranking | Jetson |
| `guides/` | Numbered Jetson guides (flash → CUDA → TensorRT → LLMs) | docs |
| `infra/` | K3s build server, GitOps by **Flux**: Helm releases, Tekton pipelines, ARC runners, Terraform, Ansible | build server |
| `scripts/repo-sync/` | Periodic sync of freightcrunch repositories (see below) | build server (CI) / any host |
| `.github/workflows/` | GitHub Actions that run on the **self-hosted ARC runners** | build server |

`origin` is `freightcrunch/cubevision-dotfiles`, a **public** fork of `n-drw/cubevision-dotfiles`
(`upstream`).

## Ground rules

- **This repo is public.** Never commit secrets, tokens, hostnames/IPs that aren't already public,
  or content from private freightcrunch repos (code, commit messages, file names). The same applies
  to **Actions logs and job summaries**, which are public too. Secrets are created out-of-band;
  document them the way `infra/pipelines/ams-bol-system/SECRETS.md` does.
- **GitOps: change files, not clusters.** Flux reconciles `infra/clusters/build-server` from `main`.
  Don't `kubectl apply`/`helm install` things by hand, except the out-of-band secrets. New
  resources must be added to the relevant `kustomization.yaml`.
- **Don't edit vendored/generated content:** `nvim-linux-x86_64/`, `infra/helm/tekton/*.yaml`
  (upstream release manifests), `infra/clusters/build-server/flux-system/` (Flux bootstrap).
- **Self-hosted runners + public repo:** workflows that use `runs-on: freightcrunch-sync` (or any
  ARC label) must trigger only on `schedule`/`workflow_dispatch`/`push` to `main`. Never use
  `pull_request`/`pull_request_target`: fork PRs would execute on the build server, next to the
  private mirrors.
- **Shell style** (see `nemoclaw/setup-openclaw.sh`): `#!/usr/bin/env bash`, `set -euo pipefail`,
  the `info`/`warn`/`error`/`section` helpers, a boxed usage header. Watch for `[ … ] && x=…` as
  the *last* command of a function: under `set -e` it silently aborts the script when the test is
  false. Use `if` instead.
- **Line endings:** commit shell scripts, YAML and Makefiles with LF (they run on Linux).
- **Verify before claiming done:** `bash -n` on scripts, `kubectl kustomize infra/helm/<dir>` for
  kustomizations, and a real run where possible (e.g. `sync-repos.sh` into a temp dir).

## Repo sync: keeping freightcrunch repositories current

### What it does

Every 4 hours, `.github/workflows/sync-freightcrunch-repos.yml` runs on the ARC runner scale set
`freightcrunch-sync`. That runner set is deployed by Flux as a Helm release
(`infra/helm/apps/freightcrunch-repo-sync.yaml`, chart `gha-runner-scale-set`). The job runs
`scripts/repo-sync/sync-repos.sh /mirrors`, which keeps a bare `--mirror` clone of each repository
in `scripts/repo-sync/repos.txt` on the persistent volume `arc-runners/freightcrunch-mirrors`:

| Repository | Default branch | Stack |
|---|---|---|
| [freightcrunch/postalentry](https://github.com/freightcrunch/postalentry) | `main` | TypeScript |
| [freightcrunch/pkg_unwrapper](https://github.com/freightcrunch/pkg_unwrapper) | `master` | Rust |
| [freightcrunch/import-analyst-be](https://github.com/freightcrunch/import-analyst-be) | `main` | C# |
| [freightcrunch/PayCBP](https://github.com/freightcrunch/PayCBP) | `main` | C# |

Default branches are detected from the remote, so renames are picked up automatically. The job
summary reports, per repo, the default-branch SHA before and after the sync and the number of new
commits. It deliberately omits commit subjects (public logs).

```
 schedule (cron 23 */4 * * *)            Flux ── HelmRelease arc-freightcrunch-sync
        │                                         │ (gha-runner-scale-set, maxRunners 1)
        ▼                                         ▼
 GitHub Actions ──► runs-on: freightcrunch-sync ─► runner pod ─► sync-repos.sh /mirrors
                                                                   │  fetch --prune (token via
                                                                   │  per-command header only)
                                                                   ▼
                                                PVC freightcrunch-mirrors (local-path, 20Gi)
                                                  postalentry.git  pkg_unwrapper.git
                                                  import-analyst-be.git  PayCBP.git
```

### One-time setup

1. **Runner registration secret.** Reuses `arc-runners/arc-github-auth` (see `SECRETS.md`). The PAT
   owner must be an admin of `freightcrunch/cubevision-dotfiles` to register repo-scoped runners.
2. **Read token for the synced repos.** Create a fine-grained PAT (or GitHub App) owned by
   `freightcrunch` with **read-only** `Contents` + `Metadata` on exactly the repos in `repos.txt`.
   Store it as the Actions secret `FREIGHTCRUNCH_SYNC_TOKEN`:
   `gh secret set FREIGHTCRUNCH_SYNC_TOKEN --repo freightcrunch/cubevision-dotfiles`
3. **Enable Actions on the fork.** Scheduled workflows are disabled on forks until enabled in
   *Actions → "I understand my workflows, go ahead and enable them"*.
4. **Lock down fork PRs.** *Settings → Actions → General → Fork pull request workflows*: require
   approval for **all** outside collaborators.
5. Merge to `main`. Flux creates the PVC and runner set (`flux get helmreleases -n arc-runners`).

### Operating it

```bash
gh workflow run sync-freightcrunch-repos.yml --repo freightcrunch/cubevision-dotfiles  # sync now
gh run list --workflow sync-freightcrunch-repos.yml --repo freightcrunch/cubevision-dotfiles

# Same script on a dev machine: regular clones, fast-forwards the default branch only,
# skips repos with uncommitted changes or a checked-out feature branch.
GH_TOKEN=$(gh auth token) SYNC_MODE=worktree SYNC_VERBOSE=1 \
  bash scripts/repo-sync/sync-repos.sh ~/src/freightcrunch
```

### Using the mirrors (agents on the build server)

- Treat `/mirrors/*.git` as a **read-only cache**. Never push to, commit in, or `gc --prune=now`
  them. Mount the PVC `readOnly: true` in any other pod.
- Work from a throwaway clone: `git clone /mirrors/pkg_unwrapper.git /tmp/pkg_unwrapper`.
- Check what changed since a known SHA:
  `git -C /mirrors/postalentry.git log --oneline <sha>..main`.
- The mirrors can be up to 4 hours stale. If you need the tip right now, trigger the workflow
  (above) or fetch from GitHub directly.
- Push changes to GitHub via normal PRs on the source repository. Mirrors are never a source of
  truth.

### Adding or removing a repository

Edit `scripts/repo-sync/repos.txt` (one `owner/repo` per line) and grant the
`FREIGHTCRUNCH_SYNC_TOKEN` read access to the new repo. Removed repos are **not** deleted from the
volume automatically: `kubectl exec` into a runner pod or a debug pod with the PVC and remove
`/mirrors/<repo>.git`.

### Troubleshooting

| Symptom | Check |
|---|---|
| Job stuck in *Queued* | `kubectl get pods -n arc-runners`, `flux get hr -n arc-runners`. Is the listener pod up and `arc-github-auth` valid? |
| `**failed**` row for a repo | Does the token still have access? Was the repo renamed or archived? Re-run locally with `GH_TOKEN=… SYNC_MODE=mirror` |
| PVC `Pending` | Expected until the first runner pod is scheduled (`local-path` uses `WaitForFirstConsumer`) |
| Permission denied writing `/mirrors` | `fsGroup: 1001` in the runner template; local-path dirs should be `0777` |

## Local LLM selection (whichllm)

`nemoclaw/setup-openclaw.sh` ranks models with [whichllm](https://github.com/Andyyyy64/whichllm)
rather than a hard-coded default. When changing the curated `MODELS` table, give each entry a
`rank_id` that whichllm knows (the base HF model id), then check the ordering with
`bash nemoclaw/setup-openclaw.sh --list-models`. Use `WHICHLLM="uvx whichllm@latest"` to test
without installing. Details: `nemoclaw/README.md` → *How models are ranked*.

## Planned work

`plan.md` covers the Hermes/NemoClaw version tracking and automated dependency updates.
