# Agent Instructions — nix-cluster (public)

This file extends the global instructions at `~/Programming/hhlab/brain/.brain/AGENT.md`.

---

## Project Context

- **BRAIN_CONTEXT**: kubernetes
- **BRAIN_REPO**: nix-cluster
- **Purpose**: NixOS-based Raspberry Pi Kubernetes cluster — host provisioning, k3s,
  Kubernetes workloads, and cluster operational tooling. Public-safe content only.
- **Private counterpart**: `../nix-cluster-private/` (not published)

---

## Public Brain Rules

- This `.brain/` directory is pushed to GitHub and Gitea — never add sensitive content here
- This directory only contains content explicitly published via `brainctl publish`
- Raw investigations live in `../nix-cluster-private/.brain/` — BRAIN_ROOT points there

---

## Start Here

Read in this order before making non-trivial changes:

1. `README.md`
2. `docs/RESTART_PLAN.md`
3. `docs/LESSONS_LEARNED.md`
4. the most recent relevant status or handoff doc in `docs/`

If the task touches Kubernetes workloads, also read:

1. `kubernetes/README.md`
2. the relevant workload README under `kubernetes/`
3. `docs/KUBERNETES_WORKLOAD_PACKAGING_DECISION.md`

---

## Core Repository Boundaries

- `nixos/` owns Raspberry Pi host provisioning, NixOS configuration, SSH, networking,
  `k3s`, firewalling, validation, and deploy workflow.
- `kubernetes/platform/` owns shared cluster platform services (ingress, observability, etc.)
- `kubernetes/operations/` owns operator tooling (cluster UIs, admin helpers)
- `kubernetes/apps/` owns migrated or cluster-native applications
- `docs/` owns runbooks, rollout notes, planning, lessons learned, and session handoffs

Do not mix host bootstrap concerns into `kubernetes/`.
Do not mix application manifests into `nixos/`.

---

## Cross-Repo Rule

You may read from these sibling repositories for context:

- `../nix-pi`
- `../nix-services`
- `../synology-services`

Do not edit those repositories without explicit user authorization.

---

## Public Vs Private References

Public repos may use anonymized placeholders such as `*.internal.example` for
Git remotes, service URLs, hostnames, and other environment-specific identifiers.

Treat those values as sanitized public-side references. Check `../nix-cluster-private`
for the real values before assuming a placeholder address is broken or misconfigured.

---

## Sandbox And Homelab DNS

Access to real homelab hostnames under `*.<homelab-domain>` should be treated as
host-network work, not ordinary sandbox-safe repo work.

Do not change repo code just because a sandboxed command reports temporary resolution
failure for a healthy homelab hostname.

---

## Cluster Shape

- 5 Raspberry Pi 4 nodes (8 GB RAM each)
- `cluster-pi-01`, `cluster-pi-02`, `cluster-pi-03` — control-plane nodes
- `cluster-pi-04`, `cluster-pi-05` — workers
- Default deploy mode: `--self-build` (each node builds its own closure on-device)
- meganix (Threadripper 2920X, 24 threads) is also a valid remote builder

---

## Tooling: Always Use `nix develop`

All cluster tooling (`kubectl`, `helm`, `cilium`, `k9s`, `stern`, `kustomize`) is
provided by the devShell — do not assume these are on PATH outside it.

```bash
nix develop --command kubectl get nodes
nix develop --command helm list -n kube-system
```

---

## Preferred Commands

- `nix run .#session-preflight`
- `nix run "path:$PWD#validate-private-config" -- <node>`
- `nix run .#validate-cluster-node -- <node>`
- `nix run .#deploy-cluster-node -- --self-build <node> <target-host>`
- `nix run .#render-observability`
- `nix run .#render-headlamp`

---

## Kubernetes Packaging Rules

- Kustomize as the top-level composition layer
- Helm selectively for upstream third-party apps
- plain YAML for repo-owned glue resources and patches

---

## Git Workflow

Run Git commands from inside `nix develop` so pre-commit hook dependencies are available.
Never use `--no-verify` to bypass missing local tools. Enter `nix develop` and rerun.

At session start:

1. `nix develop`
2. `git fetch origin`
3. `git pull --rebase origin main`
4. `git status --short --branch`

---

## Validation Expectations

Before declaring host-side changes done, validate the relevant node configs:

- server nodes must generate `k3s server`
- worker nodes must generate `k3s agent`
- workers must not receive server-only flags
- API endpoint, token, and SSH authorized keys must still be present

---

## Private Config

Treat `../nix-cluster-private` as the canonical private source of truth.

`private-config-template/` is only a tracked placeholder contract.
`nixos/hosts/private/` is legacy migration scaffolding.
