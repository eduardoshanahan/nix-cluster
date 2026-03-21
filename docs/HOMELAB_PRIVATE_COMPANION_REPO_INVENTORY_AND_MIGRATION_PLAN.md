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

Each public infrastructure repo should move toward this shape:

- tracked placeholder private input in the public repo
- real private values in a sibling private companion repo
- explicit documented default sibling path
- explicit override environment variable
- explicit validation helper that fails if the placeholder is still active

Recommended sibling layout:

```text
~/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/
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

- highest-priority remaining migration target

Current private locations and assumptions:

- gitignored shared overrides:
  `nixos/hosts/private/overrides.nix`
- gitignored host modules:
  `nixos/hosts/private/rpi-box-01.nix`
  `nixos/hosts/private/rpi-box-02.nix`
  `nixos/hosts/private/rpi-box-03.nix`
- gitignored local operator notes:
  `private/PROVISIONING_LOCAL.md`

Code-level evidence:

- `nixos/modules/private.nix` conditionally imports
  `../hosts/private/overrides.nix`
- `flake.nix` conditionally imports host modules from
  `./nixos/hosts/private/*.nix`
- docs repeatedly instruct operators to use `path:.#...` so gitignored private
  files are visible during evaluation

Private values currently mixed into this model include:

- admin username
- admin authorized SSH keys
- domains and hostnames
- host-specific service enablement and wiring
- monitoring inventory and host-local runtime divergences

Why this is still brittle:

- the canonical private source is still gitignored state inside the public repo
- evaluation behavior depends on path-based flakes seeing untracked files
- private host modules are treated as live config, not just placeholders

Recommended migration shape:

- public repo:
  `nix-pi`
- private companion repo:
  `nix-pi-private`
- tracked placeholder:
  `private-config-template/`
- override variable:
  `NIX_PI_PRIVATE_FLAKE`

Recommended migration phases:

1. Move shared private values out of `nixos/hosts/private/overrides.nix` into a
   sibling private flake.
2. Move per-host modules into private flake modules with the same host names.
3. Add `validate-private-config` for shared values needed by image builds and
   rebuilds.
4. Add host validation helpers for `rpi-box-01`, `rpi-box-02`, and
   `rpi-box-03`.
5. Rewrite docs so the private companion repo becomes canonical and
   `nixos/hosts/private/` becomes legacy migration scaffolding.

### `nix-services`

Status:

- medium-priority migration target after `nix-pi`

Current private assumptions are weaker than `nix-pi`, but they are not yet
fully standardized.

Current visible private patterns:

- policy docs allow empty placeholder private directories such as:
  `private/`
  `hosts-private/`
- some docs still describe private overlays as a valid extension point
- many service modules consume runtime secret paths under `/run/secrets/...`
- several shared service READMEs point to host-local truth in
  `../nix-pi/nixos/hosts/private/rpi-box-02.nix`

Important distinction:

- most `nix-services` secret handling is already runtime-path based, which is
  compatible with public/private separation
- the bigger problem is lack of one explicit private companion pattern for any
  shared service-level private overlays or environment-specific operator data

What probably belongs in a future `nix-services-private`:

- shared service-level private overlay modules, if any are still needed
- private operator defaults that should not live in `nix-pi`
- service-side environment-specific values that are not secrets in
  `/run/secrets` but still should not live in the public repo

What should stay out of `nix-services-private`:

- decrypted runtime secrets
- host selection and one-host divergences that belong in `nix-pi`
- secrets that are already better handled by `sops-nix` and `/run/secrets`

Recommended migration phases:

1. Audit whether `nix-services` actually needs a real evaluation-time private
   overlay today, or whether its remaining private truth is mostly host-owned in
   `nix-pi`.
2. If yes, create `nix-services-private` with a minimal tracked placeholder
   contract.
3. Add a validation helper only for values that must exist before service
   evaluation.
4. Keep runtime secret consumption on `/run/secrets/...`; do not move those
   secrets into the companion repo model just because a companion repo exists.

### `synology-services`

Status:

- lower-priority inventory target

Reason:

- it is part of the broader homelab
- it likely contains private operational data and deploy-time assumptions
- but the current migration handoff identified `nix-pi` and `nix-services` as
  the immediate next targets

Recommendation:

- inspect it after `nix-pi` and `nix-services`
- apply the same public-repo/private-companion rule if it still depends on
  gitignored local-only state

## Migration Ranking

Recommended order:

1. `nix-pi`
2. `nix-services`
3. `synology-services`

Why `nix-pi` comes first:

- it still depends directly on gitignored evaluation-time private modules
- it is central to host provisioning, bootstrap, and rebuild workflows
- it currently teaches operators to rely on `path:.#...` for private config
  visibility

Why `nix-services` comes second:

- its main secret flow already uses runtime paths rather than tracked values
- much of its remaining private truth is really host-owned in `nix-pi`
- it may need less structural migration than `nix-pi`

Why `synology-services` comes third:

- it has not yet been audited in the same detail
- it is important, but not the blocking case for standardizing the current
  Raspberry Pi and cluster workflows

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
