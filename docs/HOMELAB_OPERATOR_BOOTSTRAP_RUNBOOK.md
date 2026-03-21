# Homelab Operator Bootstrap Runbook

## Purpose

This runbook defines the standard fresh-machine checkout and validation flow for
the homelab infrastructure repositories.

It is intentionally aligned with the private companion repo convention so a new
operator machine does not depend on ad hoc local-only hidden files.

## Target Layout

Use one parent directory on every operator machine:

```text
~/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/
  nix-cluster/
  nix-cluster-private/
  nix-pi/
  nix-pi-private/
  nix-services/
  synology-services/
```

This layout keeps the default sibling paths stable across machines.

## Bootstrap Order

Clone the public and private repos as sibling pairs.

Minimum recommended set:

1. `nix-cluster`
2. `nix-cluster-private`
3. `nix-pi`
4. `nix-pi-private`
5. `nix-services`

Clone `synology-services` too if that operator machine will manage the NAS-side
services.

## Current Reality By Repo

### `nix-cluster`

This repo already follows the companion-repo convention.

Default private path:

- `../nix-cluster-private`

Override variable:

- `NIX_CLUSTER_PRIVATE_FLAKE`

Preflight validation:

```bash
cd ~/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-cluster
nix run "path:$PWD#validate-private-config" -- cluster-pi-01
nix run "path:$PWD#validate-cluster-node" -- cluster-pi-01
```

Before deploys, validate the specific node you are about to touch.

### `nix-pi`

This repo now follows the companion-repo convention.

Default private path:

- `../nix-pi-private`

Override variable:

- `NIX_PI_PRIVATE_FLAKE`

Preflight validation:

```bash
cd ~/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi
nix run "path:$PWD#validate-private-config" -- rpi-box-01
nix run "path:$PWD#validate-pi-host" -- rpi-box-01
```

Before deploys, validate the specific host you are about to touch.

### `nix-services`

This repo does not currently require an evaluation-time companion repo.

Current private workflow:

- shared modules consume runtime secret paths under `/run/secrets/...`
- host-specific private wiring and runtime divergences belong in `nix-pi` /
  `nix-pi-private`
- there is no current `private` flake input or required sibling private checkout
  for evaluation

Current bootstrap implication:

- clone `nix-services`
- keep runtime secret provisioning in the host layer, normally through
  `nix-pi` plus `sops-nix`

Current validation reality:

- validate the host-side secret provisioning and service enablement in `nix-pi`
- do not assume `nix-services` alone owns the missing private truth

Reference audit:

- `../nix-services/records/NIX_SERVICES_PRIVATE_COMPANION_AUDIT_2026-03-21.md`

### `synology-services`

This repo also does not currently require a sibling private companion repo.

Current private workflow:

- sanitized `.env.example` files are tracked
- some stacks track encrypted `.env.sops`
- deploy scripts preserve the NAS-side remote `.env` unless `--update-env` is
  explicitly requested

Current bootstrap implication:

- clone `synology-services`
- ensure `sops` is available if you need to decrypt local `.env.sops`
- treat the NAS-side `.env` as part of the runtime operator state, not as an
  accidental leftover

Reference audit:

- `../synology-services/PRIVATE_STATE_AUDIT_2026-03-21.md`

## Standard Operator Rules

On every operator machine:

1. Keep the public and private repo checkouts adjacent.
2. Prefer documented sibling defaults over machine-specific custom paths.
3. If a non-standard path is required, use the repo's override environment
   variable.
4. Run private-config validation before deploys.
5. Treat tracked template private inputs as placeholders only, never as real
   values.

## Standard Override Model

Each repo should follow this shape:

- default private companion repo in a sibling directory
- one explicit environment variable override
- validation helpers that use path-based flake evaluation where required

Current implemented override:

- `NIX_CLUSTER_PRIVATE_FLAKE`
- `NIX_PI_PRIVATE_FLAKE`

Reserved future-only name if `nix-services` ever gains a real evaluation-time
private contract:

- `NIX_SERVICES_PRIVATE_FLAKE`

## Fresh-Machine Checklist

1. Install Nix with flakes enabled.
2. Clone the public repos.
3. Clone the matching private companion repos next to them where the repo
   actually requires one today.
4. Enter each repo and run its documented validation helpers.
5. Only after validation, perform image builds, rebuilds, or deploys.

## Migration Note

This runbook still spans repos with different private models:

- `nix-cluster` already has a fully explicit companion-repo workflow
- `nix-pi` now also has a fully explicit companion-repo workflow
- `nix-services` currently relies on public evaluation plus host-owned runtime
  secrets rather than its own private flake
- `synology-services` currently relies on encrypted env files plus explicit
  remote `.env` preservation rather than its own private repo

That asymmetry is intentional and reflects the current code reality rather than
an unfinished migration.
