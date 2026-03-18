# Next Session Rollout Notes

This document now assumes we are continuing with the documented rollout plan
and using `rpi-box-01` (`192.0.2.58`) as the shared ARM builder.

## Fast Start

If starting fresh tomorrow, re-check only these facts first:

```bash
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.31 'hostname; systemctl is-active k3s; sudo k3s kubectl get nodes -o wide'
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.32 'hostname; systemctl is-active k3s'
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.33 'hostname; systemctl is-active k3s'
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.34 'hostname; systemctl is-active k3s'
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.35 'hostname; systemctl is-active k3s'
```

## Do Not Repeat These Dead Ends

Do not start by using:

```bash
nix run .#deploy-cluster-node -- cluster-pi-0N operator@192.0.2.3N
```

Reason:

- current helper does not handle `aarch64-linux` build-host requirements

Do not assume this will work either:

```bash
/run/current-system/sw/bin/nixos-rebuild switch \
  --flake path:/home/eduardo/Programming/gitea.<homelab-domain>/nix-cluster#cluster-pi-0N \
  --build-host operator@192.0.2.58 \
  --target-host operator@192.0.2.3N \
  --sudo
```

Reason:

- `rpi-box-01` is not signing its outputs today
- targets reject cross-host store copies because `require-sigs = true`

That dead end only goes away after both of these are true:

- `rpi-box-01` signs its locally built outputs
- cluster nodes trust the `rpi-box-01` public signing key

## Current Intended Tactic

The repository is now prepared for a trusted-builder rollout.

Shared assumptions:

- `rpi-box-01` remains at `192.0.2.58`
- cluster nodes trust the builder key through
  `homelab.nix.trustedBuilderPublicKeys`
- deployments use deterministic SSH options through `NIX_SSHOPTS`

Preferred deploy helper usage:

```bash
NIX_CLUSTER_BUILD_HOST='operator@192.0.2.58' \
  nix run .#deploy-cluster-node -- cluster-pi-0N operator@192.0.2.3N
```

Equivalent explicit invocation:

```bash
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
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 \
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
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.3N 'hostname; cat /etc/hostname; systemctl is-active k3s'
```

If hostname mismatch or stale cluster behavior appears:

1. reboot once
2. if still stale, wipe `/var/lib/rancher/k3s`
3. restart `k3s`

## `.32` Recovery Pattern That Worked

This sequence mattered:

1. deploy `cluster-pi-02`
2. observe `/etc/hostname = cluster-pi-02` but runtime behavior still stale
3. reboot
4. observe correct runtime hostname but stale `k3s` server behavior
5. wipe `/var/lib/rancher/k3s`
6. start `k3s`
7. verify join from `.31`

That is the best evidence we have for what may also be needed on `.33` to `.35`.

## Rollout Order

Once builder trust is working, continue in this order:

1. `cluster-pi-03` at `192.0.2.33`
2. `cluster-pi-04` at `192.0.2.34`
3. `cluster-pi-05` at `192.0.2.35`

For each node:

1. deploy the intended config with `rpi-box-01` as build host
2. verify runtime hostname and `/etc/hostname`
3. reboot once if hostname or live identity is stale
4. wipe `/var/lib/rancher/k3s` if old embedded-cluster behavior remains
5. restart `k3s`
6. verify from `cluster-pi-01`
