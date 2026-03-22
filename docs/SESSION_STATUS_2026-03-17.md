# Session Status: 2026-03-17

## Purpose

This document captures the exact state of the cluster work at the end of the
March 17, 2026 session so the next session can continue without re-discovering
today's failures.

## Executive Summary

Progress today was real:

- `cluster-pi-01` is healthy at `192.0.2.31`
- `cluster-pi-02` was successfully converted from the flashed generic-image
  state into a real second control-plane node at `192.0.2.32`
- `cluster-pi-01` and `cluster-pi-02` both show `Ready` in Kubernetes

Important remaining state:

- `192.0.2.33` still boots as `cluster-pi-01`, `k3s` active
- `192.0.2.34` still boots as `cluster-pi-01`, `k3s` active
- `192.0.2.35` still boots as `cluster-pi-01`, `k3s` activating

## Final Verified Cluster State

Verified near the end of the session:

- `192.0.2.31`:
  - hostname: `cluster-pi-01`
  - `k3s`: `active`
- `192.0.2.32`:
  - hostname: `cluster-pi-02`
  - `k3s`: `active`

Cluster view from `192.0.2.31`:

```text
NAME            STATUS   ROLES                AGE   VERSION        INTERNAL-IP
cluster-pi-01   Ready    control-plane,etcd   24h   v1.35.2+k3s1   192.0.2.31
cluster-pi-02   Ready    control-plane,etcd   70s   v1.35.2+k3s1   192.0.2.32
```

Untouched remaining nodes:

- `192.0.2.33`: `cluster-pi-01`, `k3s` `active`
- `192.0.2.34`: `cluster-pi-01`, `k3s` `active`
- `192.0.2.35`: `cluster-pi-01`, `k3s` `activating`

## What Worked

### 1. Local validation was still good

These validated cleanly before live rollout:

- `cluster-pi-01`
- `cluster-pi-02`
- `cluster-pi-03`
- `cluster-pi-04`
- `cluster-pi-05`

Important validated behavior:

- `cluster-pi-01` is `k3s server` with `--cluster-init`
- `cluster-pi-02` and `cluster-pi-03` are joining `k3s server` nodes
- `cluster-pi-04` and `cluster-pi-05` are `k3s agent`

### 2. This deploy shape worked for `cluster-pi-01`

The successful deploy command for `cluster-pi-01` was:

```bash
NIX_SSHOPTS='-F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5' \
  /run/current-system/sw/bin/nixos-rebuild switch \
  --flake 'path:#cluster-pi-01' \
  --build-host operator@192.0.2.58 \
  --target-host operator@192.0.2.31 \
  --sudo
```

Key observation:

- once the builder cache on `rpi-box-01` was warm, this path reported
  `copying 0 paths...` and switched quickly

### 3. `cluster-pi-02` eventually joined after explicit cleanup

`cluster-pi-02` did not join correctly after the first successful switch.

What finally fixed it:

1. deploy `cluster-pi-02` config onto `192.0.2.32`
2. reboot once so the runtime hostname became `cluster-pi-02`
3. stop `k3s`
4. delete stale `/var/lib/rancher/k3s`
5. start `k3s` again

After that, `cluster-pi-02` joined and became `Ready`.

## What Failed

### 1. The existing `deploy-cluster-node` helper is not good enough yet

Current helper behavior in `flake.nix`:

- wraps `nixos-rebuild switch --flake path:$PWD#<node> --target-host <target>`

Problems exposed today:

- it assumes the local workstation can build `aarch64-linux`
- it does not let the operator specify `--build-host`
- it does not set deterministic SSH options like `NIX_SSHOPTS`
- it does not use `/run/current-system/sw/bin/nixos-rebuild`

### 2. Local workstation cannot directly build these node systems

Direct local deployment failed because the workstation is `x86_64-linux` and
the node systems require `aarch64-linux`.

This is not a theory. We hit the failure directly.

### 3. `rpi-box-01` is not currently usable as a fully trusted remote builder

We verified on `rpi-box-01`:

- `require-sigs = true`
- `secret-key-files =` empty
- only `cache.nixos.org` is trusted

That means:

- `rpi-box-01` is **not** currently signing locally built outputs
- targets will reject store paths copied from `rpi-box-01`
- cross-host `--build-host operator@192.0.2.58` is not a complete permanent
  solution yet

We hit the exact failure on `cluster-pi-02`:

- copied paths from `ssh://operator@192.0.2.58`
- target rejected them because they lacked a trusted signature

### 4. Freshly flashed nodes still contain stale live `k3s` state

This was the biggest behavioral discovery of the session.

Symptoms observed on `192.0.2.32`:

- after switching to `cluster-pi-02`, `/etc/hostname` was correct
- but the running hostname initially stayed `cluster-pi-01`
- after reboot, `k3s` still behaved like it had old server state
- logs showed it opening tunnels to itself on `192.0.2.32:6443`
- it was not appearing in `cluster-pi-01`'s node list

What this means:

- the flashed nodes are not just "generic OS + no memory"
- they carry enough persistent `k3s` state that a declarative switch alone is
  not sufficient for clean identity conversion

## Commands And Tactics That Matter

### Preferred SSH style

Operators may run these commands from different workstations.

Before using any SSH or deploy command, set the identity file to a private key
that exists on the current machine and whose public key is already present in
the cluster admin authorized-keys set.

Use this consistently:

```bash
export NIX_CLUSTER_IDENTITY_FILE="${NIX_CLUSTER_IDENTITY_FILE:-$HOME/.ssh/operator_ed25519}"

ssh -i "$NIX_CLUSTER_IDENTITY_FILE" -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5
```

Reason:

- local `~/.ssh/config` permissions caused one avoidable failure
- `-F /dev/null` made behavior deterministic
- the identity file must come from the current operator machine rather than a
  hardcoded workstation-specific path

### Builder host

Current effective ARM build host:

- `rpi-box-01`
- `192.0.2.58`
- repo checkout exists at `~/nix-cluster`

### Known-good control-plane verification

From `192.0.2.31`:

```bash
sudo k3s kubectl get nodes -o wide
```

## Strong Recommendations For Tomorrow

### Immediate next live action

Do **not** jump straight into `.33` deployment blindly.

First:

1. encode today's findings into the deploy workflow
2. decide what the official first-boot cleanup step is
3. only then continue with `.33`, `.34`, `.35`

### Most likely successful rollout pattern for `.33`, `.34`, `.35`

For each remaining node:

1. deploy the intended node config
2. ensure runtime hostname matches the declarative hostname
3. wipe stale `/var/lib/rancher/k3s` if it still carries old cluster identity
4. start or restart `k3s`
5. verify from `cluster-pi-01`

Likely order:

1. `cluster-pi-03` at `192.0.2.33`
2. `cluster-pi-04` at `192.0.2.34`
3. `cluster-pi-05` at `192.0.2.35`

### Repository changes that should happen next

These are the most important code/doc fixes to make in this repo:

1. replace or extend `deploy-cluster-node` so it supports:
   - `--build-host`
   - deterministic SSH options via `NIX_SSHOPTS`
   - maybe an explicit `--mode self-build` fallback for first bootstrap
2. document that a cross-host builder only works when:
   - the builder signs outputs
   - the targets trust that builder key
3. document the stale-`k3s`-state issue clearly
4. add an explicit "first boot from shared image" runbook:
   - identify node by IP/MAC
   - deploy target config
   - verify runtime hostname
   - reset stale `k3s` state if present
   - verify join

## Important Open Question

The generic bootstrap intent in the docs says the shared image should not start
`k3s`, but the live flashed nodes clearly did boot with `k3s` already active.

That mismatch still needs to be explained cleanly tomorrow.

Possibilities:

- the flashed artifact was not actually the intended generic image
- the generic image still contains enough old state to activate `k3s`
- the documented intent is ahead of the actual flashed artifact state

Do not assume this is resolved.

## Working Rule

We may read sibling repositories for context.

We must not edit them without explicit authorization.
