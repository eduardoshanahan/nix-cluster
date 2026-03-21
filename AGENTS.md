# AGENTS.md

## Purpose

This file tells coding agents how to work safely and effectively in
`nix-cluster/`.

This directory is for a NixOS-based Raspberry Pi Kubernetes cluster that is
meant to integrate cleanly with the existing homelab while staying easy to
learn and operate.

## Start Here

Read in this order before making non-trivial changes:

1. `README.md`
2. `HOMELAB_AND_CLUSTER_CONTEXT.md`
3. `docs/RESTART_PLAN.md`
4. `docs/LESSONS_LEARNED.md`
5. the most recent relevant status or handoff doc in `docs/`

If the task touches Kubernetes workloads, also read:

1. `kubernetes/README.md`
2. the relevant workload README under `kubernetes/`
3. `docs/KUBERNETES_WORKLOAD_PACKAGING_DECISION.md`

If the task touches observability, also read:

1. `docs/CLUSTER_OBSERVABILITY_PHASE1_PLAN.md`
2. `docs/CLUSTER_OBSERVABILITY_PHASE2_PLAN.md`

## Core Repository Boundaries

Preserve the separation of concerns that this repo is built around:

- `nixos/` owns Raspberry Pi host provisioning, NixOS configuration, SSH,
  networking, `k3s`, firewalling, validation, and deploy workflow.
- `kubernetes/platform/` owns shared cluster platform services such as ingress,
  observability components, and future cluster-wide capabilities.
- `kubernetes/operations/` owns operator tooling such as cluster UIs and admin
  helpers.
- `kubernetes/apps/` owns migrated or cluster-native applications.
- `docs/` owns runbooks, rollout notes, planning, lessons learned, and session
  handoffs.

Do not mix host bootstrap concerns into `kubernetes/`.
Do not mix application manifests into `nixos/`.

## Cross-Repo Rule

You may read from these sibling repositories for context:

- `../nix-pi`
- `../nix-services`
- `../synology-services`

Do not edit those repositories without explicit user authorization.

When changes in `nix-cluster` depend on those repos, keep the boundary clear in
your notes and avoid silently implementing cross-repo assumptions.

## Operational Model To Respect

This repo intentionally moved away from fragile per-node SD-card images.

Prefer and preserve this workflow:

- one shared bootstrap image
- node-specific configuration applied after first boot
- post-boot deploys for most iteration
- explicit validation before rollout
- clear recovery steps for stale `k3s` state

Do not reintroduce a design that depends on maintaining five distinct bootstrap
images unless the user explicitly asks for that change.

## Important Current Facts

As documented in the March 18, 2026 status and rollout notes:

- the intended cluster shape is 5 Raspberry Pi 4 nodes with 8 GB RAM each
- `cluster-pi-01`, `cluster-pi-02`, and `cluster-pi-03` are control-plane nodes
- `cluster-pi-04` and `cluster-pi-05` are workers
- `rpi-box-01` is the shared ARM builder
- cluster nodes trust builder keys through
  `homelab.nix.trustedBuilderPublicKeys`

If you are changing bootstrap, deploy, or recovery logic, read the latest
session-status and rollout docs first and update them if your change alters the
operator story.

## Implementation Map

Use this mental model when editing:

- `flake.nix`: main entrypoint, node definitions, helper apps, dev shell
- `nixos/modules/options.nix`: repo-specific option surface under `homelab.*`
- `nixos/modules/base.nix`: shared OS defaults and node exporter
- `nixos/modules/ssh.nix`: SSH access model and embedded authorized keys
- `nixos/modules/k3s-common.nix`: shared `k3s` behavior and firewall rules
- `nixos/modules/validation.nix`: assertions that prevent bad server/agent
  flag generation
- `nixos/profiles/`: reusable role/base profiles
- `nixos/hosts/`: thin host-specific modules
- `private-config-template/`: tracked placeholder private flake contract
- `nixos/hosts/private/`: legacy examples from the pre-companion-repo model
- `kubernetes/platform/observability/`: cluster telemetry workloads
- `kubernetes/operations/`: cluster operational tooling
- `kubernetes/apps/`: application workloads that run on top of the platform

Try to keep host files thin and shared behavior centralized.

## Preferred Commands

Prefer the repo helpers in `flake.nix` over ad hoc commands when they fit:

- `nix run "path:$PWD#validate-private-config" -- <node>`
- `nix run .#validate-cluster-node -- <node>`
- `nix run .#deploy-cluster-node -- <node> <target-host>`
- `nix run .#render-observability`
- `nix run .#render-headlamp`
- `nix develop`

For deploy work, preserve the helper-driven model around:

- `NIX_CLUSTER_BUILD_HOST`
- `NIX_CLUSTER_SSHOPTS`
- `--build-host`
- `--self-build`

Do not replace the helper flow with undocumented one-off deploy commands unless
the task is specifically about recovery or debugging.

## Git Workflow

Run Git commands for this directory from inside `nix develop` so the expected
tooling and hook dependencies are available.

At the start of a session in this repo:

1. enter `nix develop`
2. run `git fetch origin`
3. run `git pull --rebase origin main` unless the user explicitly wants a
   different branch strategy
4. inspect `git status --short --branch` before making changes

Do not skip Git hooks during normal operations.
Do not use `--no-verify` unless the user explicitly asks for it or there is a
documented emergency recovery reason.

If you need to commit, prefer this flow:

1. `nix develop`
2. run formatting, validation, or other expected checks
3. run normal Git commands without bypassing hooks
4. push the finished work to `origin` before ending the session when the task is
   complete and the user has not asked to keep it local

## Validation Expectations

Before declaring host-side changes done, validate the relevant node configs.

Pay special attention to:

- server nodes must generate `k3s server`
- worker nodes must generate `k3s agent`
- workers must not receive server-only flags
- API endpoint, token, and SSH authorized keys must still be present where
  required

If you change `k3s` flag logic, validation assertions in
`nixos/modules/validation.nix` should usually be updated in the same change.

## Private Config And Secrets

Treat the private companion repo as the canonical private source of truth.

For `nix-cluster`, the intended local default is:

- `../nix-cluster-private`

`private-config-template/` is only a tracked placeholder contract and must not
be treated as a real private source.

`nixos/hosts/private/` is now legacy migration scaffolding and example shape,
not the preferred active workflow.

Expected private data includes:

- SSH authorized keys
- cluster bootstrap token
- real homelab domain values
- trusted builder public keys
- any future secret-adjacent overrides

Do not commit real secret values into tracked files.
Use the private companion repo for real values and the tracked template/example
files only as documented shape.

## Kubernetes Packaging Rules

Keep using the established pattern:

- Kustomize as the top-level composition layer
- Helm selectively for upstream third-party apps
- plain YAML for repo-owned glue resources and patches

Do not introduce a GitOps controller or a completely different packaging model
unless the user asks for that architectural change.

Keep manifests readable and easy to learn from.

## Documentation Expectations

This repo depends heavily on good handoff docs.

When a change affects rollout, recovery, deploy behavior, packaging decisions,
or operator expectations:

- update the relevant doc in `docs/`
- keep dates explicit
- prefer concrete runbook steps over vague summaries
- record real operational discoveries so they are not lost next session

## Editing Style

Match the existing style:

- simple, explicit Nix modules
- thin host files
- readable docs aimed at future operators
- practical explanations over clever abstractions

When in doubt, optimize for clarity, reversibility, and a clean operator
workflow.
