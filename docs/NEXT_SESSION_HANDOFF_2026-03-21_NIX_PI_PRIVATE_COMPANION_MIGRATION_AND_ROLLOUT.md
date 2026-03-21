# Next Session Handoff: 2026-03-21 `nix-pi` Private Companion Migration And Rollout

## Purpose

This document is the restart point for the session that migrated `nix-pi` from
tracked in-repo private host files to a real sibling private companion repo,
rolled that migration out to the Raspberry Pi hosts, and uncovered one
remaining follow-up item on `rpi-box-02`.

The next session should use this file to avoid re-investigating:

- how the `nix-pi` migration was implemented
- what was already deployed
- what still needs verification or cleanup
- what the exact next step should be before starting the same pattern in
  `nix-services`

## Executive Summary

At the end of this session:

- `nix-pi` now follows the same explicit private-flake pattern as
  `nix-cluster`
- a new sibling private repo exists locally:
  `../nix-pi-private`
- the old tracked private files under `nix-pi/nixos/hosts/private/*.nix`
  were removed from the public repo
- all three hosts were rebuilt successfully against the new public/private split:
  - `rpi-box-01`
  - `rpi-box-02`
  - `rpi-box-03`
- `rpi-box-03` was rebuilt using `rpi-box-02` as the remote builder, as
  required
- a missing declarative Tailscale import on `rpi-box-02` was found and restored

The one unresolved operational detail is:

- after restoring Tailscale on `rpi-box-02`, the targeted redeploy succeeded
  and `tailscale.service` was started, but the final SSH-based post-start
  verification commands to that host began timing out

That means the migration and rollout are mostly done, but the next session
should start by confirming final live health on `rpi-box-02`, especially
Tailscale.

## What Was Changed

### 1. `nix-pi` now uses a tracked placeholder private input

New public placeholder contract:

- `nix-pi/private-config-template/flake.nix`
- `nix-pi/private-config-template/modules/shared.nix`

New option surface:

- `nix-pi/nixos/modules/options.nix`
  - added `lab.privateConfig.source`
  - added `lab.privateConfig.isPlaceholder`

New validation module:

- `nix-pi/nixos/modules/validation.nix`

The public repo now fails clearly if the placeholder is still active or if
`lab.adminAuthorizedKeys` is empty.

### 2. `nix-pi` flake wiring now mirrors `nix-cluster`

Key file:

- `nix-pi/flake.nix`

Important changes:

- added flake input:
  - `private.url = "path:./private-config-template"`
- added `private` to `outputs`
- added helper functions to resolve:
  - shared private module
  - host-specific private modules
- added special arg:
  - `piRepoRoot = ./.`
- added helper apps:
  - `validate-private-config`
  - `validate-pi-host`

Important helper behavior:

- helpers use `self` for the public flake path instead of assuming the current
  working directory
- helpers support:
  - `NIX_PI_PRIVATE_FLAKE`
  - `NIX_PI_NIX_SERVICES_FLAKE`

That second override was added because `rpi-box-02` already relied on newer
`nix-services` Prometheus options than the locked input in `nix-pi/flake.lock`.

### 3. Public host definitions were separated from private host modules

New public host entry files:

- `nix-pi/nixos/hosts/rpi-box-01.nix`
- `nix-pi/nixos/hosts/rpi-box-02.nix`
- `nix-pi/nixos/hosts/rpi-box-03.nix`

These keep host identity public and thin.

Removed tracked private host files from the public repo:

- `nix-pi/nixos/hosts/private/overrides.nix`
- `nix-pi/nixos/hosts/private/rpi-box-01.nix`
- `nix-pi/nixos/hosts/private/rpi-box-02.nix`
- `nix-pi/nixos/hosts/private/rpi-box-03.nix`

`nix-pi/nixos/modules/private.nix` no longer imports
`../hosts/private/overrides.nix`.

### 4. A new real local private repo was created

Local sibling repo:

- `nix-pi-private/`

Important files:

- `nix-pi-private/flake.nix`
- `nix-pi-private/README.md`
- `nix-pi-private/modules/shared.nix`
- `nix-pi-private/modules/rpi-box-01.nix`
- `nix-pi-private/modules/rpi-box-02.nix`
- `nix-pi-private/modules/rpi-box-03.nix`

Important implementation detail:

The migrated private host modules still need to reference the public repo's
encrypted SOPS files under `nix-pi/secrets/`.

To make that stable, the private modules now consume the public repo path
through:

- `piRepoRoot`

instead of fragile old relative paths like:

- `../../../secrets/secrets.yaml`

This is one of the most important design decisions in the migration. Keep it.

### 5. Documentation was updated to the new operator model

The public docs were updated to reflect:

- sibling `nix-pi-private`
- explicit helper validation
- explicit `--override-input private`
- optional helper override:
  `NIX_PI_NIX_SERVICES_FLAKE`

Key updated files:

- `nix-pi/README.md`
- `nix-pi/AGENTS.md`
- `nix-pi/DOCUMENTATION_INDEX.md`
- `nix-pi/docs/lifecycle/SETUP.md`
- `nix-pi/docs/lifecycle/PROVISIONING.md`
- `nix-pi/docs/lifecycle/REMOTE_BUILDS.md`
- `nix-pi/docs/policy/CONFIDENTIALITY.md`
- `nix-pi/docs/policy/HOST_RUNTIME_DIVERGENCES.md`
- `nix-pi/docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`
- `nix-pi/nixos/hosts/private/README.md`
- `nix-pi/private/PROVISIONING_LOCAL.md`

## Validation Work Completed

### Public/private evaluation checks

These all passed during the session:

- `validate-private-config` for:
  - `rpi-box-01`
  - `rpi-box-02`
  - `rpi-box-03`
- `validate-pi-host` for:
  - `rpi-box-01`
  - `rpi-box-02`
  - `rpi-box-03`

The helper commands were run with:

- `NIX_PI_PRIVATE_FLAKE=/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi-private`
- `NIX_PI_NIX_SERVICES_FLAKE=/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-services`

The `NIX_PI_NIX_SERVICES_FLAKE` override mattered because the current
`nix-pi/flake.lock` was behind the sibling `nix-services` checkout until
`nix flake update nix-services` was run in this session.

### Raw evaluation proofs captured during the session

These succeeded:

- `rpi-box-01` hostname evaluation
- `rpi-box-03` toplevel derivation evaluation

That confirmed the new private repo wiring worked before the first live deploy.

## Live Deployments Completed

### 1. `rpi-box-01`

Deployed successfully with:

- target host: `eduardo@rpi-box-01`
- build host: `eduardo@rpi-box-01`

Important result:

- rebuild succeeded
- basic post-deploy checks were good

Verified live after deploy:

- hostname correct
- `tailscale` active
- `traefik` active
- `pihole` active
- `promtail` active
- `/etc/ssh/authorized_keys/eduardo` present
- `/etc/ssl/certs/homelab-root-ca.crt` present

Note:

- the first Tailscale check mistakenly used `tailscaled.service`
- the real unit name from the shared module is:
  - `tailscale.service`

### 2. `rpi-box-02`

Deployed successfully with:

- target host: `eduardo@rpi-box-02`
- build host: `eduardo@rpi-box-02`

Verified live after the first deploy:

- hostname correct
- `grafana` active
- `prometheus` active
- `alertmanager` active
- `homepage` active
- `promtail` active
- `/etc/nix/rpi-box-02-priv.pem` present

Important discovery:

- Tailscale was missing from the live config after the first deploy
- this was not a runtime crash
- it was a declarative omission

Root cause:

- `nix-pi-private/modules/rpi-box-02.nix` did not import:
  - `inputs.nix-services.services.tailscale`
- and did not declare:
  - `sops.secrets.tailscale-authkey`
  - `services.tailscaleCompose`

That omission was then fixed in the private repo.

### 3. `rpi-box-03`

Deployed successfully with:

- target host: `eduardo@rpi-box-03`
- build host: `eduardo@rpi-box-02`

This remote-builder constraint was preserved exactly as intended.

Verified live after deploy:

- hostname correct
- `traefik` active
- `pihole` active
- `loki` active
- `promtail` active
- homelab CA file present

## The `rpi-box-02` Tailscale Follow-Up

### What was fixed

Tailscale was restored declaratively on `rpi-box-02` by updating:

- `nix-pi-private/modules/rpi-box-02.nix`

The fix added:

- import:
  - `inputs.nix-services.services.tailscale`
- secret:
  - `sops.secrets.tailscale-authkey`
- service config:
  - `services.tailscaleCompose`

The restored service config matches the pattern on `rpi-box-01`:

- enable = true
- hostname = `rpi-box-02`
- auth key from `/run/secrets/tailscale-authkey`
- advertise route:
  - `192.168.1.0/24`
- `acceptRoutes = true`
- `acceptDns = false`
- `firewallMode = "nftables"`

### What happened during the targeted redeploy

The second `rpi-box-02` rebuild succeeded.

Important activation lines observed:

- `adding secret: tailscale-authkey`
- `the following new units were started: ... tailscale.service`

This is strong evidence that the declarative fix was applied correctly.

### What remains unresolved

After that targeted redeploy, the follow-up SSH verification commands to
`rpi-box-02` began hanging, including:

- `systemctl is-active tailscale`
- `docker ps ... | grep tailscale`
- `journalctl -u tailscale ...`
- even a bounded:
  - `timeout 15 ssh rpi-box-02 '...'`

That means:

- the rebuild itself finished
- `tailscale.service` was started during activation
- but final post-start interactive verification from this session did not
  complete

Do not assume Tailscale is broken.
Do not assume it is healthy either.

Treat it as:

- deployment applied
- final live confirmation still needed

## Current Git State

### `nix-pi`

The public repo has not been committed yet.

Current changes include:

- updated docs
- updated `flake.nix`
- updated `flake.lock`
- new validation module
- new placeholder private input
- deletion of tracked private host files
- new thin public host files

### `nix-pi-private`

This repo was initialized locally with:

- `git init`

It also has not been committed yet.

Current files are staged, but `modules/rpi-box-02.nix` shows an additional
modification from the Tailscale restore.

That means the next session should inspect `git -C nix-pi-private status` again
before committing.

## Exact Commands/Patterns Worth Reusing

### Validation

```bash
export NIX_PI_PRIVATE_FLAKE=/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi-private
export NIX_PI_NIX_SERVICES_FLAKE=/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-services

nix run "path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi#validate-private-config" -- rpi-box-01
nix run "path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi#validate-pi-host" -- rpi-box-01
```

Swap `rpi-box-01` for the other host names as needed.

### Direct rebuilds

`rpi-box-01`:

```bash
NIX_PI_PRIVATE_FLAKE=/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi-private \
nixos-rebuild switch \
  --flake path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi#rpi-box-01 \
  --override-input nix-services path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-services \
  --override-input private path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi-private \
  --target-host eduardo@rpi-box-01 \
  --build-host eduardo@rpi-box-01 \
  --sudo
```

`rpi-box-02`:

```bash
NIX_PI_PRIVATE_FLAKE=/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi-private \
nixos-rebuild switch \
  --flake path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi#rpi-box-02 \
  --override-input nix-services path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-services \
  --override-input private path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi-private \
  --target-host eduardo@rpi-box-02 \
  --build-host eduardo@rpi-box-02 \
  --sudo
```

### Remote-builder rebuild

`rpi-box-03` through `rpi-box-02`:

```bash
NIX_PI_PRIVATE_FLAKE=/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi-private \
nixos-rebuild switch \
  --flake path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi#rpi-box-03 \
  --override-input nix-services path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-services \
  --override-input private path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi-private \
  --target-host eduardo@rpi-box-03 \
  --build-host eduardo@rpi-box-02 \
  --sudo
```

## Recommended Next Session Start Order

Read in this order:

1. this handoff
2. `nix-cluster/docs/HOMELAB_PRIVATE_COMPANION_REPO_INVENTORY_AND_MIGRATION_PLAN.md`
3. `nix-cluster/docs/HOMELAB_OPERATOR_BOOTSTRAP_RUNBOOK.md`
4. `nix-pi/README.md`
5. `nix-pi/AGENTS.md`
6. `nix-pi-private/README.md`

Then do this exact next work:

1. Re-check live access to `rpi-box-02`.
2. Confirm the final live state of `tailscale` on `rpi-box-02`.
3. If Tailscale is healthy, commit:
   - `nix-pi`
   - `nix-pi-private`
4. If Tailscale is not healthy, fix only that issue first and redeploy only
   `rpi-box-02`.
5. Once `nix-pi` is finished and committed, begin the same companion-repo
   migration for `nix-services`.

## Recommended Success Criteria For The Next Session

The next session should count as successful if it achieves:

1. final confirmed live health on `rpi-box-02`, including Tailscale
2. clean committed state in:
   - `nix-pi`
   - `nix-pi-private`
3. a clear start on the `nix-services` companion-repo migration using the same
   explicit public/private pattern

## Key Lesson To Preserve

The most important implementation lesson from this session is:

- keep the public repo responsible for tracked placeholders, encrypted public
  SOPS files, and thin host identity
- keep the private repo responsible for real environment-specific Nix modules
- pass the public repo root into the private modules explicitly when the private
  config needs to reference public encrypted artifacts

Do not regress to:

- tracked private host files inside the public repo
- ad hoc gitignored public-repo local files as the canonical source of truth
- fragile `../../../...` path assumptions across repo boundaries
