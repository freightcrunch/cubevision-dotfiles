# Plan: Hermes on NemoClaw at the latest version, with routine dependency updates

Status: **proposed** · Drafted 2026-09-16 · Owner: TBD

## Goals

1. Run **Hermes** (via NemoClaw) on the Jetson Orin Nano, **tracking the latest NemoClaw release**
   reproducibly, and wired to the local llama.cpp (TurboQuant) endpoint chosen by whichllm.
2. **Routinely update every dependency installed by `cubevision-dotfiles`** using GitHub Actions on
   the Helm-deployed ARC runners. Updates arrive as reviewable PRs, and machines converge from
   `main`.

Non-goals: running NemoClaw in production (it is alpha), multi-Jetson fleet management, changing
the Flux/Tekton architecture.

## Current state (as of 2026-09-16)

### Hermes / NemoClaw

| Area | Today | Problem |
|---|---|---|
| Install | `nemoclaw/setup-openclaw.sh` and `make nemoclaw` both run `curl … nemoclaw.sh \| bash` unpinned | The installer defaults to the **`lkg`** tag, currently **v0.0.124**. Latest tag is **v0.0.126** (2026-09-16). "Latest" isn't what we get, and nothing records what *is* installed |
| Downgrade trap | — | The installer **refuses** to replace an installed version with an older `lkg`. After one manual upgrade, the default unpinned run fails |
| Hermes | README mentions `NEMOCLAW_AGENT=hermes` only | Interactive onboarding. The provider/endpoint/model aren't captured, so a rebuild loses them |
| Provider | llama-server on `127.0.0.1:8080`, entered by hand in the wizard | Can be non-interactive: `NEMOCLAW_PROVIDER=custom`, `NEMOCLAW_ENDPOINT_URL`, `NEMOCLAW_MODEL`, `COMPATIBLE_API_KEY` (verified in `src/lib/onboard/providers.ts`) |
| Model | Now ranked by whichllm (`--with-llamacpp` = `auto`) | `auto` can change the served model whenever benchmarks change. Fine for manual runs, but an unattended 24/7 gateway needs a pin |
| llama.cpp | `feature/turboquant-kv-cache` branch HEAD, `--depth 1` | Built SHA isn't recorded, so there's no rollback target |
| Script name | `setup-openclaw.sh` | Agent-agnostic now; the name is misleading for Hermes |

### Dependencies installed or pinned by this repo

| Dependency | Where pinned | Update path today |
|---|---|---|
| NemoClaw CLI / OpenShell | installer default `lkg` | manual |
| Hermes agent image | pulled by NemoClaw per release | follows NemoClaw |
| llama-cpp-turboquant | branch HEAD | manual re-run |
| whichllm | `uv tool install` (unpinned) | `make whichllm` |
| uv, fnm/Node 22, Python 3.13, Rust nightly, mold | `host/Makefile` vars / installers | manual |
| nvm | `v0.39.7` in `scripts/install.sh`, `ssh-deploy-task.yaml` | manual |
| K3s / Flux / Helm | `infra/bootstrap/install-k3s.sh` (`v1.36.1+k3s1`, `2.8.8`, `4.2.0`); `infra/ansible/inventory/hosts.yml` + `terraform/variables.tf` still say `v1.31.4+k3s1` (**drift**) | manual |
| Flux controllers | `flux-system/gotk-components.yaml` (v2.8.8) | `flux bootstrap` |
| Helm charts | HelmRelease `version:` ranges (`65.x`, `0.x`, `9.x`, `>=0.9.0 <1.0.0`) | Flux floats within the range; **majors never** |
| Tekton | vendored `infra/helm/tekton/*.yaml` (Pipelines v1.13.1, Triggers v0.36.0, Dashboard v0.69.0) | manual re-vendor |
| Container images | `ghcr.io/actions/actions-runner:latest`, `rust:1.82-bookworm`, `node:20-bookworm`, `alpine:3.20`, `golang:1.23` | `latest` floats uncontrolled; the rest are stale |
| Terraform providers | `infra/terraform/main.tf` (no lock file) | manual |
| Ansible collections | `requirements.yml` (`>=` floors) | manual |
| Go modules | `installer/go.mod` | manual |
| Neovim | vendored `nvim-linux-x86_64/`, `wsl/nvim/lazy-lock.json` | manual |
| GitHub Actions | `actions/checkout@v4` | manual |

## Design

**The repo is the source of truth for versions. CI proposes bumps; machines pull and apply.**

```
             ┌──────────────── build server (K3s, Flux) ────────────────┐
 schedule ─► │ ARC runner set "cubevision-deps" (HelmRelease)            │
             │   ├─ renovate          → PRs: charts, images, tf, go,    │
             │   │                      actions, versions.env (regex)   │
             │   └─ deps-refresh      → PRs: re-vendor Tekton,          │
             │                          whichllm ranking snapshot       │
             └───────────────────────────────┬──────────────────────────┘
                                             │ review + merge to main
             ┌───────────────────────────────▼──────────────────────────┐
             │ Flux reconciles infra/  (charts, images, runner sets)     │
             │ Jetson: systemd --user timer → git pull → apply-versions  │
             │   (NemoClaw tag, Hermes rebuild, llama.cpp SHA, model)    │
             └───────────────────────────────────────────────────────────┘
```

Why **Renovate** rather than Dependabot: Dependabot can't bump Flux `HelmRelease` chart
versions, Kubernetes manifest images, or the shell-script pins (`K3S_VERSION=`, `nvm v0.39.7`,
NemoClaw tag), so most of the inventory would stay manual. Renovate covers all of these natively
(`flux`, `kubernetes`, `helm-values`, `terraform`, `ansible-galaxy`, `gomod`, `github-actions`,
`nix`) plus `customManagers` regex for the rest. It runs as a plain container, so it fits the
existing ARC runners.

## Phases

### Phase 1: Single version manifest (`versions.env`)

- Add `versions.env` at the repo root. Each pin carries a Renovate annotation:
  ```bash
  # renovate: datasource=github-tags depName=NVIDIA/NemoClaw
  NEMOCLAW_INSTALL_TAG=v0.0.126
  # renovate: datasource=git-refs depName=https://github.com/TheTom/llama-cpp-turboquant currentValue=feature/turboquant-kv-cache
  LLAMACPP_REF=<sha>
  # renovate: datasource=pypi depName=whichllm
  WHICHLLM_VERSION=0.5.16
  # renovate: datasource=github-releases depName=k3s-io/k3s
  K3S_VERSION=v1.36.1+k3s1
  # renovate: datasource=github-releases depName=fluxcd/flux2
  FLUX_VERSION=2.8.8
  # renovate: datasource=github-releases depName=helm/helm
  HELM_VERSION=4.2.0
  # renovate: datasource=github-releases depName=nvm-sh/nvm
  NVM_VERSION=v0.39.7
  NEMOCLAW_AGENT=hermes
  LLAMACPP_MODEL=qwen3.5-9b     # pinned output of `--list-models`; `auto` only for manual runs
  ```
- Source it from `nemoclaw/setup-openclaw.sh`, `host/Makefile`, `scripts/install.sh`,
  `infra/bootstrap/install-k3s.sh`. Env vars still override it.
- Fix the K3s drift: Ansible and Terraform read the same value (or the docs point at `versions.env`).
- **Done when** `git grep -nE 'v0\.39\.7|2\.8\.8|v1\.3[16]\.'` finds matches only in `versions.env`
  and vendored files.

### Phase 2: Hermes on the latest NemoClaw, reproducibly

- Rename `nemoclaw/setup-openclaw.sh` → `nemoclaw/setup.sh` and keep a one-line
  `setup-openclaw.sh` shim for existing docs/muscle memory. Add `--agent openclaw|hermes`.
- Always export `NEMOCLAW_INSTALL_TAG` from `versions.env`. Add `--channel lkg|latest|pinned`:
  - `pinned` (default): the `versions.env` tag, so runs are reproducible and immune to the downgrade trap.
  - `latest`: resolve the newest `v*` tag (`gh api repos/NVIDIA/NemoClaw/tags`) for an ad-hoc try.
  - `lkg`: NVIDIA's maintained tag. Warn when it is older than the installed version.
- Non-interactive Hermes onboarding against the local endpoint:
  ```bash
  # env must reach `bash` (the installer), not `curl`
  curl -fsSL https://www.nvidia.com/nemoclaw.sh | \
    NEMOCLAW_AGENT=hermes NEMOCLAW_NON_INTERACTIVE=1 NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1 \
    NEMOCLAW_SANDBOX_NAME=cubevision-hermes \
    NEMOCLAW_PROVIDER=custom NEMOCLAW_ENDPOINT_URL=http://<jetson-lan-ip>:8080/v1 \
    NEMOCLAW_MODEL="$LLAMACPP_MODEL" COMPATIBLE_API_KEY=not-needed \
    NEMOCLAW_INSTALL_TAG="$NEMOCLAW_INSTALL_TAG" \
    bash
  ```
  Confirm whether the OpenShell sandbox reaches `127.0.0.1` or needs the LAN IP / Docker bridge.
  If it needs one of those, bind llama-server to that interface only, never `0.0.0.0` on an
  untrusted network.
- Model changes after onboarding: `nemohermes inference set --model <m> --provider custom --sandbox cubevision-hermes`,
  not a re-onboard.
- Record state in `~/.local/state/cubevision/installed.env`: NemoClaw version, llama.cpp SHA,
  model key, whichllm version. `make info` prints it along with `nemohermes --version`.
- Tune for 8 GB: `LLAMACPP_MODEL` stays a curated key. Hermes needs tool calls and long context, so
  evaluate `qwen3.5-9b` (whichllm #1 curated, ~10 tok/s est.) against `lfm2.5-2.6b` (agentic-tuned,
  fastest) with `WHICHLLM_PROFILE=general` and the `coding` profile. Record the decision in
  `versions.env`.
- **Done when** a fresh Jetson reaches a working `nemohermes cubevision-hermes connect` session with
  zero prompts, and a re-run is a no-op.

### Phase 3: Renovate on the ARC runners

- Add ARC runner set `cubevision-deps` (copy of `infra/helm/apps/freightcrunch-repo-sync.yaml`
  without the PVC; `maxRunners: 1`).
- `.github/workflows/renovate.yml`: `schedule` (e.g. daily 04:00) + `workflow_dispatch` only (public
  repo, see AGENTS.md), `runs-on: cubevision-deps`, `renovatebot/github-action`. Auth via a GitHub
  App scoped to `freightcrunch/cubevision-dotfiles` (contents + pull requests: write).
- `renovate.json5`:
  - `flux`, `kubernetes`, `helm-values` managers over `infra/**`. `github-actions`, `terraform`
    (plus commit `.terraform.lock.hcl`), `ansible-galaxy`, `gomod`, `nix`.
  - `customManagers` regex over `versions.env` (the annotations above).
  - Tighten the floating ranges into exact versions so bumps show up as PRs: HelmRelease
    `65.x` → exact, `actions-runner:latest` → pinned tag + digest.
  - `packageRules`: automerge patch/minor for images, charts and actions once CI is green; group
    Tekton, K3s/Flux/Helm, NemoClaw (`automerge: false`, alpha) and llama.cpp (`automerge: false`,
    needs a Jetson build); majors always manual; schedule `before 6am on monday` to batch noise.
  - `ignorePaths`: `nvim-linux-x86_64/**`, `infra/clusters/build-server/flux-system/**`.
- **Done when** the Renovate dashboard issue lists every row of the inventory table as detected.

### Phase 4: Things Renovate can't bump (`deps-refresh` workflow)

Weekly workflow on `cubevision-deps` that opens PRs via `peter-evans/create-pull-request`:

- **Tekton**: when the Renovate-bumped version in `versions.env` changes, download the release YAML
  into `infra/helm/tekton/` and render the diff.
- **Flux components**: `flux install --export` at `FLUX_VERSION` → `gotk-components.yaml`.
- **whichllm ranking snapshot**: run `bash nemoclaw/setup-openclaw.sh --list-models` (no GPU
  needed, it simulates the Jetson) and commit `nemoclaw/model-ranking.md`. When the #1 curated
  model differs from `LLAMACPP_MODEL`, the PR proposes the change instead of the Jetson silently
  switching.
- **Neovim**: bump `lazy-lock.json` via headless `nvim --headless "+Lazy! update" +qa`; update the
  vendored `nvim-linux-x86_64` from the latest stable release tarball.

### Phase 5: Apply on the Jetson (pull-based)

- `scripts/apply-versions.sh`: idempotent. It compares `versions.env` against `installed.env` and
  only acts on differences:
  NemoClaw tag changed → installer with `NEMOCLAW_INSTALL_TAG`, then `nemohermes cubevision-hermes rebuild`;
  `LLAMACPP_REF` changed → rebuild llama.cpp at that SHA; model changed → rewrite the service and
  `nemohermes inference set`; `WHICHLLM_VERSION` changed → `uv tool install whichllm==…`.
- `systemd --user` timer `cubevision-update.timer` (daily, `RandomizedDelaySec=1h`): `git pull --ff-only`
  on `main` → `apply-versions.sh` → health check (`curl :8080/health`, a one-shot Hermes prompt).
  On failure it rolls back to the previous `installed.env` values and sends a notification
  (ntfy/Slack webhook, TBD).
- Why not an ARC runner on the Jetson: the Jetson is not in the K3s cluster, a runner would put
  unreviewed CI code on the inference box, and pull-based updates need no inbound access.
- **Done when** merging a NemoClaw bump PR results in the Jetson running that version within 24 h,
  with a rollback demonstrated once.

## Risks

| Risk | Mitigation |
|---|---|
| NemoClaw is alpha; releases ship almost daily and config schemas change | Pin in `versions.env`, never automerge, and use the one-prompt smoke test before the timer marks success |
| Self-hosted runners attached to a **public** repo | Only `schedule`/`workflow_dispatch` triggers, fork-PR approval required, GitHub App tokens scoped to this repo (see AGENTS.md) |
| whichllm ranking flips the gateway model unattended | Unattended runs use the pinned `LLAMACPP_MODEL`; ranking changes arrive as PRs (Phase 4) |
| whichllm assumes an fp16 KV cache, so it under-counts what TurboQuant fits | Rank at 8k ctx; serve context from the curated table; validate on-device before pinning |
| Renovate PR noise | Grouping, weekly schedule, automerge only for patch/minor with green CI |
| A llama.cpp fork branch force-push loses the pinned SHA | Keep the last good `llama-server` binary alongside the build, and pin `LLAMACPP_REF` to a SHA Renovate has seen |

## Open questions

1. Does the OpenShell sandbox reach host `127.0.0.1:8080`, or do we need the Docker bridge / LAN IP?
2. Should Hermes use the local model exclusively, or keep a hosted NVIDIA endpoint as fallback
   (needs `NVIDIA_INFERENCE_API_KEY` on the Jetson)?
3. Notification channel for failed Jetson updates?
4. GitHub App vs fine-grained PAT for Renovate. An App is preferred (short-lived tokens), but it
   needs an org admin to create it.
