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
  nix-services-private/
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
6. `nix-services-private`

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

This repo has not completed the companion-repo migration yet.

Current private workflow:

- gitignored `nixos/hosts/private/overrides.nix`
- gitignored `nixos/hosts/private/<host>.nix`
- path-based flake evaluation to include those files

Current bootstrap implication:

- clone `nix-pi`
- clone `nix-pi-private` as the intended future sibling private repo
- until the migration lands, ensure the required private config is present in
  the current expected locations before building or rebuilding hosts

Current validation workaround:

- use path-based flake refs for builds and rebuilds
- confirm the expected private files exist locally
- only then run `nix build path:.#...` or `nixos-rebuild --flake path:.#...`

Target post-migration state:

- default private path:
  `../nix-pi-private`
- override variable:
  `NIX_PI_PRIVATE_FLAKE`
- repo helper:
  `validate-private-config`

### `nix-services`

This repo also has not completed the companion-repo migration yet.

Current private workflow:

- shared modules mostly consume runtime secret paths under `/run/secrets/...`
- some docs still allow private overlays, but there is not yet one explicit
  companion-repo contract

Current bootstrap implication:

- clone `nix-services`
- clone `nix-services-private` as the intended future sibling private repo
- keep runtime secret provisioning in the host layer, normally through
  `nix-pi` plus `sops-nix`

Current validation workaround:

- validate the host-side secret provisioning and service enablement in `nix-pi`
- do not assume `nix-services` alone owns the missing private truth

Target post-migration state:

- default private path:
  `../nix-services-private`
- override variable:
  `NIX_SERVICES_PRIVATE_FLAKE`
- repo helper:
  `validate-private-config`

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

Reserved target names for the next migrations:

- `NIX_PI_PRIVATE_FLAKE`
- `NIX_SERVICES_PRIVATE_FLAKE`

## Fresh-Machine Checklist

1. Install Nix with flakes enabled.
2. Clone the public repos.
3. Clone the matching private companion repos next to them.
4. Enter each repo and run its documented validation helpers.
5. Only after validation, perform image builds, rebuilds, or deploys.

## Migration Note

Until `nix-pi` and `nix-services` finish their migrations, this runbook is a
hybrid:

- `nix-cluster` already has a fully explicit companion-repo workflow
- `nix-pi` and `nix-services` are documented here as the intended target shape
  plus their current temporary validation reality

That temporary mismatch is expected. The point of this runbook is to standardize
the destination so future migrations converge on one operator story.
