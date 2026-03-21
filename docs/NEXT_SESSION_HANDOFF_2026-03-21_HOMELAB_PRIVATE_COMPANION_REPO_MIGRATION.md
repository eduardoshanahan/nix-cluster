# Next Session Handoff: 2026-03-21 Homelab Private Companion Repo Migration

## Purpose

This handoff began as the restart point for spreading the
private-companion-repo pattern beyond `nix-cluster`.

The `nix-cluster` migration was completed in this session and should now be
treated as the working reference implementation.

The original next-session focus was:

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

## Consolidated Outcome

This work has now progressed far beyond the original planning stage.

As of 2026-03-21, the homelab-wide audit conclusion is:

- `nix-cluster`
  - explicit companion repo required
- `nix-pi`
  - explicit companion repo required
- `nix-services`
  - no evaluation-time companion repo currently required
- `synology-services`
  - no sibling companion repo currently required

The correct higher-level rule is now:

- every repo must have an explicit private-state contract
- companion repos are used where evaluation-time private values require them
- other repos may use different explicit models if they are documented and
  operationally sound

## Files To Read First Next Session

- `README.md`
- `AGENTS.md`
- `docs/PRIVATE_COMPANION_REPO_CONVENTION.md`
- `docs/NEXT_SESSION_HANDOFF_2026-03-21_CLUSTER_NETWORKING_AND_PRIVATE_CONFIG.md`
- `docs/HOMELAB_PRIVATE_COMPANION_REPO_INVENTORY_AND_MIGRATION_PLAN.md`
- `docs/HOMELAB_OPERATOR_BOOTSTRAP_RUNBOOK.md`

## Important Constraints For Next Session

- do not edit sibling repos without explicit user authorization
- preserve the repo/private-companion separation
- avoid inventing machine-specific paths ad hoc
- keep the bootstrap story simple enough for a new operator machine
- prefer explicit validation helpers over silent evaluation assumptions

## Consolidated Success Criteria Achieved

This body of work now achieved:

1. a clear homelab-wide private-state convention
2. an inventory of current private-data locations across the sibling repos
3. a ranked migration order with completed audits
4. a bootstrap runbook for new operator machines
5. finished `nix-pi` rollout through `rpi-box-03`
6. explicit audit records for `nix-services` and `synology-services`

## Stop Point

`nix-cluster` is in good shape and fully deployed, and the homelab-wide
private-state audit sweep is complete for the currently active repos.

The best next-session starting point is:

1. read this handoff
2. read `docs/PRIVATE_COMPANION_REPO_CONVENTION.md`
3. read `docs/HOMELAB_PRIVATE_COMPANION_REPO_INVENTORY_AND_MIGRATION_PLAN.md`
4. read `docs/HOMELAB_OPERATOR_BOOTSTRAP_RUNBOOK.md`
5. read the latest repo-specific audit or rollout record relevant to the task
6. continue from the now-documented explicit private-state model rather than
   re-opening the companion-repo question from scratch
