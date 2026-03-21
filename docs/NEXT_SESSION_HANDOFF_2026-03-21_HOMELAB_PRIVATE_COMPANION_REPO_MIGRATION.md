# Next Session Handoff: 2026-03-21 Homelab Private Companion Repo Migration

## Purpose

This handoff is for the next session whose goal is to spread the
private-companion-repo pattern beyond `nix-cluster`.

The `nix-cluster` migration was completed in this session and should now be
treated as the working reference implementation.

The next session should focus on:

- documenting the cross-repo convention clearly
- inventorying other repos that still depend on gitignored private directories
- planning the least-painful migration path for each one

## What Was Completed In This Session

### 1. `nix-cluster` private config model was replaced

`nix-cluster` no longer treats `nixos/hosts/private/overrides.nix` as the
canonical source of private values.

It now uses:

- tracked placeholder private input:
  `private-config-template/`
- real local private companion repo:
  `../nix-cluster-private`
- explicit override variable:
  `NIX_CLUSTER_PRIVATE_FLAKE`

### 2. The new workflow is validated by repo helpers

`nix-cluster` now has:

- `validate-private-config`
- `validate-cluster-node`
- `deploy-cluster-node`

All of them are wired to the explicit private flake input path.

### 3. The new workflow was proven on the live cluster

The updated repo state was deployed successfully to:

- `cluster-pi-01`
- `cluster-pi-02`
- `cluster-pi-03`
- `cluster-pi-04`
- `cluster-pi-05`

Final live verification at the end of the session:

- all five nodes `Ready`
- all five nodes report correct hostname
- all five nodes have `k3s` `active`
- Traefik healthy
- MetalLB healthy
- Headlamp reachable externally
- `kube-state-metrics` reachable externally
- Prometheus on `rpi-box-02` still scrapes
  `https://kube-state-metrics.<homelab-domain>:443/metrics` with health `up`

### 4. The repo state was committed

`nix-cluster` commit created in this session:

- `2088bee` `Switch nix-cluster to explicit private flake input`

## The Broader Problem Still Remaining

The homelab still has multiple places where private values live as:

- gitignored directories
- local-only files
- machine-specific untracked state

That means `nix-cluster` is fixed, but the overall homelab private-config story
is not yet standardized.

The next session should solve that at the design and documentation level before
starting more ad hoc migrations.

## Recommended Next Session Goal

Define and document the homelab-wide private companion repo convention, then use
it to plan migrations for:

- `nix-pi`
- `nix-services`
- any other repo in `hhlab-insfrastructure` that still depends on private
  local-only directories

## Recommended Work Plan

### Phase 1. Inventory current private directories across the homelab

Start by listing where private state currently lives.

Likely targets:

- `nix-pi`
- `nix-services`
- possibly parts of `synology-services`

Goal:

- identify which private files are required for evaluation
- identify which are required only for deployment or runtime
- identify which values are duplicated across repos

### Phase 2. Decide whether any values should become shared

There are two possible shapes:

- per-repo private companion repos only
- a hybrid model with a future shared `homelab-private` repo

Recommendation:

- do not build a shared private repo first
- first migrate each repo to the private-companion pattern independently
- only centralize later if duplicated values become painful

### Phase 3. Write one operator bootstrap runbook

Create a single operator-facing doc that answers:

- what repos must be cloned on a fresh machine
- what exact directory layout is expected
- how to validate private config before deploys
- how to override default private paths if needed

The recommended standardized layout is:

```text
~/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/
  nix-cluster/
  nix-cluster-private/
  nix-pi/
  nix-pi-private/
  nix-services/
  nix-services-private/
```

### Phase 4. Plan the next actual migration target

Best likely next candidate:

- `nix-pi`

Reason:

- it is central to operator workflows
- it already has known private host files
- it influences monitoring and builder-related workflows

After `nix-pi`, likely next:

- `nix-services`

## Files To Read First Next Session

- `README.md`
- `AGENTS.md`
- `docs/PRIVATE_COMPANION_REPO_CONVENTION.md`
- `docs/NEXT_SESSION_HANDOFF_2026-03-21_CLUSTER_NETWORKING_AND_PRIVATE_CONFIG.md`

Then inspect:

- `../nix-pi`
- `../nix-services`

for their current private-config assumptions.

## Important Constraints For Next Session

- do not edit sibling repos without explicit user authorization
- preserve the repo/private-companion separation
- avoid inventing machine-specific paths ad hoc
- keep the bootstrap story simple enough for a new operator machine
- prefer explicit validation helpers over silent evaluation assumptions

## Success Criteria For The Next Session

The next session should count as successful if it produces:

1. a clear homelab-wide migration convention
2. an inventory of current private-data locations across the sibling repos
3. a ranked migration order
4. a bootstrap runbook for new operator machines

It does not need to finish migrating every repo in one session.

## Stop Point

`nix-cluster` is in good shape and fully deployed.

The best next-session starting point is:

1. read this handoff
2. read `docs/PRIVATE_COMPANION_REPO_CONVENTION.md`
3. read `docs/HOMELAB_PRIVATE_COMPANION_REPO_INVENTORY_AND_MIGRATION_PLAN.md`
4. read `docs/HOMELAB_OPERATOR_BOOTSTRAP_RUNBOOK.md`
5. inspect `nix-pi` and `nix-services` private-data assumptions
6. write the next repo migration against that shared convention
