# Private Companion Repo Convention

## Purpose

This document defines the intended homelab-wide pattern for private,
environment-specific, and secret-adjacent configuration.

The goal is to stop relying on scattered gitignored directories that only exist
on some operator machines, and to replace them with a standard private-companion
repository model that works consistently across:

- multiple operator hosts
- local evaluation
- deploy helpers
- remote builder workflows
- future fresh-machine bootstrap

## The Pattern

Each public infrastructure repository should have a private companion
repository.

Examples:

- `nix-cluster` + `nix-cluster-private`
- `nix-pi` + `nix-pi-private`
- `nix-services` + `nix-services-private`

When a repository has private values, the public repo should:

- keep a tracked placeholder or template private input
- fail clearly if the placeholder is still active
- document the expected local private companion checkout path
- allow an override variable for non-standard layouts

The private repo should:

- be a normal private Git repository
- be cloned on every operator machine
- contain the real environment-specific values
- avoid mixing unrelated private data from other repos unless explicitly shared

## Standard Checkout Layout

Use the same parent directory on every operator machine.

Recommended layout:

```text
~/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/
  nix-cluster/
  nix-cluster-private/
  nix-pi/
  nix-pi-private/
  nix-services/
  nix-services-private/
```

This gives every repo a predictable sibling path.

That matters because it lets helpers default to a stable location without each
operator host inventing its own layout.

## Why This Pattern

This model is preferred over ad hoc gitignored local files because it:

- makes the private input explicit
- works on more than one operator host
- can be cloned onto builders and admin machines intentionally
- supports reproducible operator bootstrap
- makes missing private config fail early and visibly
- preserves public/private separation without smuggling secrets into tracked
  repo state

## What Belongs In Private Companion Repos

Typical contents:

- SSH authorized keys
- real domain values
- bootstrap tokens
- trusted builder public keys
- per-environment endpoints
- secret-adjacent operational config that should not live in the public repo

Avoid using companion repos as a dumping ground for every secret in the
homelab. They should stay focused on configuration that the paired public repo
actually consumes.

## Shared Data vs Per-Repo Data

There are two valid models:

1. Per-repo private companions
2. One shared private repo for everything

For this homelab, the recommended long-term shape is a hybrid:

- use per-repo companion repos for repo-specific private structure
- add a future shared `homelab-private` repo only if duplicated values become
  painful across multiple repos

Do not start with a giant all-secrets monorepo unless there is a clear need for
it. The simplest useful standard is:

- one public repo
- one private companion repo

## Operator Rules

When using this pattern:

- clone both the public repo and its private companion on each operator host
- keep the checkout paths consistent across hosts
- validate private config before deploys
- do not depend on hidden gitignored files inside public repos as the canonical
  source of truth

If a non-standard path is needed temporarily, use a documented environment
variable rather than hardcoding machine-specific assumptions into the repo.

## Current `nix-cluster` Status

`nix-cluster` already follows this pattern now.

Current shape:

- public repo: `nix-cluster`
- private companion: `../nix-cluster-private`
- tracked placeholder contract:
  `nix-cluster/private-config-template/`
- override variable:
  `NIX_CLUSTER_PRIVATE_FLAKE`

The migration for `nix-cluster` is complete enough to serve as the reference
implementation for the other infrastructure repos.

## How To Bootstrap A New Operator Machine

For each public/private repo pair:

1. clone the public repo
2. clone the private companion repo next to it
3. run the repo's private-config validation helper
4. run the repo's normal validation commands
5. only then perform deploys or rollouts

For `nix-cluster`, that means:

```bash
cd ~/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-cluster
nix run "path:$PWD#validate-private-config" -- cluster-pi-01
nix run "path:$PWD#validate-cluster-node" -- cluster-pi-01
```

## Migration Rule For Other Repos

When migrating another repo to this pattern, do not begin by moving every
private file at once.

Instead:

1. inventory the current gitignored private files
2. identify the minimum private values needed for evaluation and deploy
3. create the private companion repo
4. add a tracked placeholder/template in the public repo
5. add explicit validation that the placeholder is not still active
6. update docs and bootstrap instructions
7. only then remove the old implicit local-only assumptions

This keeps the migration reversible and easier to debug.
