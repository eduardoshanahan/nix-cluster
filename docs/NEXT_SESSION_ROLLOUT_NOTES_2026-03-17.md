# Next Session Rollout Notes

This document now assumes we are continuing with the documented rollout plan
and using `rpi-box-01` (`192.0.2.58`) as the shared ARM builder.

## Fast Start

If starting fresh tomorrow, re-check only these facts first:

```bash
export NIX_CLUSTER_IDENTITY_FILE="${NIX_CLUSTER_IDENTITY_FILE:-$HOME/.ssh/operator_ed25519}"

ssh -i "$NIX_CLUSTER_IDENTITY_FILE" -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.31 'hostname; systemctl is-active k3s; sudo k3s kubectl get nodes -o wide'
ssh -i "$NIX_CLUSTER_IDENTITY_FILE" -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.32 'hostname; systemctl is-active k3s'
ssh -i "$NIX_CLUSTER_IDENTITY_FILE" -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.33 'hostname; systemctl is-active k3s'
ssh -i "$NIX_CLUSTER_IDENTITY_FILE" -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.34 'hostname; systemctl is-active k3s'
ssh -i "$NIX_CLUSTER_IDENTITY_FILE" -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.35 'hostname; systemctl is-active k3s'
```

`NIX_CLUSTER_IDENTITY_FILE` must point to a private key that exists on the
current operator machine and whose public key is present in the cluster admin
authorized-keys set.

Expected healthy end-state after the March 18 session:

- `.31` through `.35` should all report their correct hostnames
- `.31`, `.32`, `.33` should be control-plane nodes
- `.34`, `.35` should be worker nodes
- `sudo k3s kubectl get nodes -o wide` on `.31` should show all five nodes
  `Ready`

## Do Not Repeat These Dead Ends

Do not fall back to the old assumption that a plain deploy helper invocation is
enough in every case:

```bash
nix run .#deploy-cluster-node -- cluster-pi-0N operator@192.0.2.3N
```

That is now valid only when the target already trusts the configured builder or
when `NIX_CLUSTER_BUILD_HOST` is set appropriately.

Do not bypass the repo helper with ad hoc `nixos-rebuild` commands unless you
have a specific recovery reason. The helper now bakes in the SSH behavior and
builder flow that worked.

The earlier builder dead end is resolved now, but it is still useful to
remember why it failed before:

- unsigned cross-host store paths were rejected by targets
- builder trust had to be configured explicitly on cluster nodes
- first-conversion nodes still needed recovery steps even after trust was fixed

## Current Intended Tactic

The repository is now prepared for a trusted-builder rollout.

Shared assumptions:

- `rpi-box-01` remains at `192.0.2.58`
- cluster nodes trust the builder key through
  `homelab.nix.trustedBuilderPublicKeys`
- deployments use deterministic SSH options through `NIX_SSHOPTS`

Preferred deploy helper usage:

```bash
export NIX_CLUSTER_IDENTITY_FILE="${NIX_CLUSTER_IDENTITY_FILE:-$HOME/.ssh/operator_ed25519}"

NIX_CLUSTER_BUILD_HOST='operator@192.0.2.58' \
NIX_CLUSTER_SSHOPTS="-i $NIX_CLUSTER_IDENTITY_FILE -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5" \
  nix run .#deploy-cluster-node -- cluster-pi-0N operator@192.0.2.3N
```

Equivalent explicit invocation:

```bash
export NIX_CLUSTER_IDENTITY_FILE="${NIX_CLUSTER_IDENTITY_FILE:-$HOME/.ssh/operator_ed25519}"

NIX_CLUSTER_SSHOPTS="-i $NIX_CLUSTER_IDENTITY_FILE -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5" \
nix run .#deploy-cluster-node -- \
  --build-host operator@192.0.2.58 \
  cluster-pi-0N \
  operator@192.0.2.3N
```

This helper now:

- uses `/run/current-system/sw/bin/nixos-rebuild`
- exports deterministic `NIX_SSHOPTS`
- supports `--build-host`
- supports `--self-build` for recovery

## Builder Trust Checklist

Before relying on the cross-host path, verify these facts on `rpi-box-01`:

```bash
export NIX_CLUSTER_IDENTITY_FILE="${NIX_CLUSTER_IDENTITY_FILE:-$HOME/.ssh/operator_ed25519}"

ssh -i "$NIX_CLUSTER_IDENTITY_FILE" -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 \
  operator@192.0.2.58 \
  'sudo nix config show | rg "require-sigs|secret-key-files|trusted-public-keys"'
```

Operationally, we need:

- `require-sigs = true`
- `secret-key-files` set on `rpi-box-01`
- the corresponding public key present in `homelab.nix.trustedBuilderPublicKeys`
  for cluster nodes

If those facts are not all true yet, use the recovery fallback below instead of
forcing a broken cross-host deploy.

## Recovery Fallback

If builder trust is not ready yet, or if a node needs an isolated first
conversion, use target self-build:

```bash
nix run .#deploy-cluster-node -- \
  --self-build \
  cluster-pi-0N \
  operator@192.0.2.3N
```

But expect:

- a very large first-time store copy
- slow first conversion

Then verify:

```bash
export NIX_CLUSTER_IDENTITY_FILE="${NIX_CLUSTER_IDENTITY_FILE:-$HOME/.ssh/operator_ed25519}"

ssh -i "$NIX_CLUSTER_IDENTITY_FILE" -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.3N 'hostname; cat /etc/hostname; systemctl is-active k3s'
```

If hostname mismatch or stale cluster behavior appears:

1. reboot once
2. if still stale as a control-plane node, wipe `/var/lib/rancher/k3s`
3. if still stale as a worker, wipe `/var/lib/rancher/k3s` and
   `/etc/rancher/node/password`
4. restart `k3s`

## `.32` Recovery Pattern That Worked

This sequence mattered:

1. deploy `cluster-pi-02`
2. observe `/etc/hostname = cluster-pi-02` but runtime behavior still stale
3. reboot
4. observe correct runtime hostname but stale `k3s` server behavior
5. wipe `/var/lib/rancher/k3s`
6. start `k3s`
7. verify join from `.31`

That is the best evidence we have for what may also be needed on future
control-plane recoveries.

## Worker Recovery Pattern That Worked

For worker first-conversion recovery, the March 18 session showed this pattern:

1. deploy the worker config
2. observe `/etc/hostname` changed but runtime hostname still stale
3. reboot once
4. if the worker still reports duplicate hostname or node-password rejection:
5. stop `k3s`
6. wipe `/var/lib/rancher/k3s`
7. delete `/etc/rancher/node/password`
8. start `k3s`
9. verify join from `.31`

This was the sequence that finally brought `cluster-pi-05` in cleanly.

## Rollout Order

The original rollout order is now complete:

1. `cluster-pi-03` at `192.0.2.33`
2. `cluster-pi-04` at `192.0.2.34`
3. `cluster-pi-05` at `192.0.2.35`

For future node recovery or rebuild work, keep this checklist:

1. deploy the intended config with `rpi-box-01` as build host
2. verify runtime hostname and `/etc/hostname`
3. reboot once if hostname or live identity is stale
4. if it is a control-plane node and old embedded-cluster behavior remains,
   wipe `/var/lib/rancher/k3s`
5. if it is a worker and duplicate-hostname / node-password rejection remains,
   wipe `/var/lib/rancher/k3s` and `/etc/rancher/node/password`
6. restart `k3s`
7. verify from `cluster-pi-01`
