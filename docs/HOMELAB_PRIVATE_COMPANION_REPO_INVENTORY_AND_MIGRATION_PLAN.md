# Homelab Private Companion Repo Inventory And Migration Plan

## Purpose

This document turns the `nix-cluster` private-companion-repo convention into a
homelab-wide migration plan.

It inventories where private or local-only state still lives across the sibling
repositories and ranks the recommended migration order.

The reference implementation is now:

- public repo: `nix-cluster`
- private companion repo: `nix-cluster-private`

## Scope

This inventory is based on the current documented and code-visible state in:

- `../nix-cluster`
- `../nix-pi`
- `../nix-services`
- `../synology-services`

The goal here is planning and operator clarity, not an immediate forced
cross-repo rewrite.

## Standard Convention

Each public infrastructure repo that has evaluation-time private values should
move toward this shape:

- tracked placeholder private input in the public repo
- real private values in a sibling private companion repo
- explicit documented default sibling path
- explicit override environment variable
- explicit validation helper that fails if the placeholder is still active

Recommended sibling layout when a repo truly needs a private companion:

```text
~/infra/
  nix-cluster/
  nix-cluster-private/
  nix-pi/
  nix-pi-private/
  nix-services/
  nix-services-private/
```

## Inventory

### `nix-cluster`

Status:

- migrated

Current private contract:

- tracked placeholder:
  `private-config-template/`
- real private source:
  `../nix-cluster-private`
- override variable:
  `NIX_CLUSTER_PRIVATE_FLAKE`

Current validation story:

- `nix run "path:$PWD#validate-private-config" -- <node>`
- `nix run "path:$PWD#validate-cluster-node" -- <node>`
- `nix run "path:$PWD#deploy-cluster-node" -- <node> <target-host>`

Private values currently expected there include:

- cluster bootstrap token
- admin authorized SSH keys
- trusted builder public keys
- real domain values
- host-specific private modules for cluster nodes

Migration status:

- complete enough to serve as the homelab reference implementation

### `nix-pi`

Status:

- migrated

Current private contract:

- public repo:
  `nix-pi`
- real private source:
  `nix-pi-private`
- tracked placeholder:
  `private-config-template/`
- override variable:
  `NIX_PI_PRIVATE_FLAKE`

Current validation story:

- `nix run "path:$PWD#validate-private-config" -- <host>`
- `nix run "path:$PWD#validate-pi-host" -- <host>`

Migration status:

- completed and live on:
  - `rpi-box-01`
  - `rpi-box-02`
  - `rpi-box-03`
- now serves as the Pi-host reference implementation of the companion pattern

### `nix-services`

Status:

- audited after `nix-pi`

Current result:

- a real evaluation-time private companion flake is **not currently required**
- the public repo already evaluates without sibling private files
- most private inputs are runtime secret paths under `/run/secrets/...`
- remaining non-secret divergences are host-owned in `nix-pi-private`

Reference audit:

- `../nix-services/records/NIX_SERVICES_PRIVATE_COMPANION_AUDIT_2026-03-21.md`

What this means operationally:

- do not create `nix-services-private` just for symmetry
- keep runtime secret consumption on `/run/secrets/...`
- keep host-owned exceptions in `nix-pi` / `nix-pi-private`
- reserve `nix-services-private` for a future case where shared
  service-level private values are truly needed at evaluation time

Migration status:

- audit complete
- no active companion-flake migration required today

### `synology-services`

Status:

- audited after `nix-services`

Current result:

- a sibling private companion repo is **not currently required**
- the repo already uses an explicit encrypted-env deployment model built around:
  - `.env.example`
  - optional tracked `.env.sops`
  - preserved remote NAS-side `.env`
- deploy scripts already handle the private-state flow directly

Reference audit:

- `../synology-services/PRIVATE_STATE_AUDIT_2026-03-21.md`

What this means operationally:

- do not create `synology-services-private` just for symmetry
- keep the current encrypted-env and remote `.env` deploy model
- revisit only if the repo later gains a real non-`.env` private contract that
  benefits from separate private versioning

## Migration Ranking

Recommended order:

1. `nix-pi`
2. `nix-services`
3. `synology-services`

Why `nix-pi` came first:

- it previously depended directly on gitignored evaluation-time private modules
- it was central to host provisioning, bootstrap, and rebuild workflows
- it was the highest-value companion-pattern migration target

Why `nix-services` was audited second:

- its main secret flow already used runtime paths rather than tracked values
- much of its remaining private truth was host-owned in `nix-pi`
- the audit confirmed that no evaluation-time private companion repo is needed
  right now

Why `synology-services` comes third:

- it was the remaining repo most likely to need an explicit private-state audit
- the audit confirmed it already has a different explicit model and does not
  need a sibling private repo today

## Shared Rules For All Future Migrations

When migrating any repo to the companion pattern:

1. Inventory current private files and directories first.
2. Separate evaluation-time private values from runtime secrets.
3. Keep runtime secrets outside Git and outside the Nix store.
4. Add a tracked placeholder private contract in the public repo.
5. Add an explicit sibling default path plus override variable.
6. Add validation helpers before removing the old workflow.
7. Update bootstrap docs in the same change.

## Definition Of Done For Each Repo Migration

A repo should only count as migrated when all of these are true:

1. The canonical private source is a sibling private companion repo.
2. The public repo has a tracked placeholder private contract.
3. Missing private config fails clearly and early.
4. Operators no longer need ad hoc gitignored files inside the public repo as
   the canonical source of truth.
5. Bootstrap docs explain the expected checkout layout and validation commands.
