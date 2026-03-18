# Session Status: 2026-03-18

## Purpose

This document captures the exact state of the cluster work at the end of the
March 18, 2026 session.

This session completed the intended five-node rollout and converted
`rpi-box-01` into a real signed ARM builder for the cluster.

## Executive Summary

Final outcome:

- `rpi-box-01` now signs Nix outputs and is usable as the shared ARM builder
- `cluster-pi-01`, `cluster-pi-02`, and `cluster-pi-03` are `Ready`
  control-plane nodes
- `cluster-pi-04` and `cluster-pi-05` are `Ready` worker nodes
- the cluster is now at the intended 3 control-plane + 2 worker shape

Key repo/workflow outcomes:

- `nix-pi` commit `120e642` configured `rpi-box-01` as a Nix signing builder
- `nix-cluster` commit `9ae9664` added trusted ARM builder rollout support
- `nix-cluster` commit `a9b7dfc` fixed worker `k3s` flag generation

## Final Verified Cluster State

Verified from `192.0.2.31` near the end of the session:

```text
NAME            STATUS   ROLES                AGE   VERSION        INTERNAL-IP
cluster-pi-01   Ready    control-plane,etcd   34h   v1.35.2+k3s1   192.0.2.31
cluster-pi-02   Ready    control-plane,etcd   10h   v1.35.2+k3s1   192.0.2.32
cluster-pi-03   Ready    control-plane,etcd   43m   v1.35.2+k3s1   192.0.2.33
cluster-pi-04   Ready    <none>               26m   v1.35.2+k3s1   192.0.2.34
cluster-pi-05   Ready    <none>               14s   v1.35.2+k3s1   192.0.2.35
```

Per-node runtime summary:

- `192.0.2.31`: hostname `cluster-pi-01`, `k3s` `active`
- `192.0.2.32`: hostname `cluster-pi-02`, `k3s` `active`
- `192.0.2.33`: hostname `cluster-pi-03`, `k3s` `active`
- `192.0.2.34`: hostname `cluster-pi-04`, `k3s` `active`
- `192.0.2.35`: hostname `cluster-pi-05`, `k3s` `active`

## What Worked

### 1. Signed builder setup on `rpi-box-01`

This is now real, not theoretical.

Verified live on `192.0.2.58`:

- `require-sigs = true`
- `secret-key-files = /etc/nix/rpi-box-01-priv.pem`

Builder public key used by cluster nodes:

```text
rpi-box-01:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
```

### 2. Cross-host deploys now work when trust is present

This was proven by rebuilding `cluster-pi-02` with:

```bash
NIX_CLUSTER_BUILD_HOST='operator@192.0.2.58' \
NIX_CLUSTER_SSHOPTS='-i /home/eduardo/.ssh/thinkpad_ed25519 -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5' \
  nix run .#deploy-cluster-node -- cluster-pi-02 operator@192.0.2.32
```

That build happened on `rpi-box-01`, the signed paths were accepted by
`cluster-pi-02`, and the switch completed cleanly.

### 3. First conversion still needs a separate recovery mindset

Even after the builder path worked, first conversion of freshly flashed nodes
still behaved differently from steady-state rebuilds.

What consistently happened on `.33`, `.34`, and `.35`:

1. declarative switch succeeded
2. `/etc/hostname` changed immediately
3. runtime hostname could still remain `cluster-pi-01`
4. reboot or stale-state cleanup was still needed before the node joined cleanly

### 4. Control-plane recovery pattern is now proven

For `cluster-pi-03` at `192.0.2.33`, the successful sequence was:

1. self-build deploy of `cluster-pi-03`
2. verify `/etc/hostname = cluster-pi-03` but runtime hostname still stale
3. reboot once
4. observe `k3s` still behaving like an old embedded server
5. stop `k3s`
6. wipe `/var/lib/rancher/k3s`
7. start `k3s`
8. verify `cluster-pi-03` joined as `Ready`

### 5. Worker recovery pattern is now proven

For both workers, the successful pattern was:

1. self-build deploy of the intended worker config
2. verify `/etc/hostname` changed but runtime hostname still stale
3. reboot once
4. if the worker still reports duplicate hostname / stale node password:
   - stop `k3s`
   - wipe `/var/lib/rancher/k3s`
   - delete `/etc/rancher/node/password`
   - start `k3s`
5. verify the worker joins from `cluster-pi-01`

This sequence was required on `cluster-pi-05`.

`cluster-pi-04` recovered after reboot once the worker flags were corrected.

## What Failed

### 1. Worker nodes were still receiving server-only flags

This was the biggest repo bug discovered on March 18.

Observed failures on `cluster-pi-04`:

- `k3s agent` rejected `--cluster-cidr`
- after that was fixed, `k3s agent` rejected `--disable=servicelb`

That proved the shared `k3s` flag logic was still too broad.

Final fix:

- move `--cluster-cidr` to server-only flags
- move `--service-cidr` to server-only flags
- move `--disable=servicelb` to server-only flags
- move `--disable=traefik` to server-only flags
- add validation assertions so workers cannot receive those flags again

### 2. Runtime hostname lag still matters operationally

The declarative hostname alone is not enough for first conversion.

We saw again that:

- `/etc/hostname` can be correct
- runtime hostname can still be stale
- node registration then fails in ways that look like `k3s` problems but are
  really identity problems first

### 3. Worker duplicate-hostname rejection has a second stale-state path

For workers we saw an additional symptom not highlighted enough on March 17:

- stale `/etc/rancher/node/password`

The agent log on `.34` and `.35` reported:

- duplicate hostname
- node password rejected

For worker recovery, that file matters alongside `/var/lib/rancher/k3s`.

## Commands And Tactics That Matter

### Preferred SSH style

For this environment, use:

```bash
ssh -i ~/.ssh/thinkpad_ed25519 \
  -F /dev/null \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=accept-new \
  -o BatchMode=yes \
  -o ConnectTimeout=5
```

### Preferred builder-backed deploy

For nodes that already trust `rpi-box-01`:

```bash
NIX_CLUSTER_BUILD_HOST='operator@192.0.2.58' \
NIX_CLUSTER_SSHOPTS='-i /home/eduardo/.ssh/thinkpad_ed25519 -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5' \
  nix run .#deploy-cluster-node -- cluster-pi-0N operator@192.0.2.3N
```

### First-conversion fallback

For a node that does not yet trust the builder:

```bash
NIX_CLUSTER_SSHOPTS='-i /home/eduardo/.ssh/thinkpad_ed25519 -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5' \
  nix run .#deploy-cluster-node -- --self-build cluster-pi-0N operator@192.0.2.3N
```

### Known-good cluster verification

From `192.0.2.31`:

```bash
sudo k3s kubectl get nodes -o wide
```

## Recommendations For Next Session

The urgent bootstrap work is done.

Next session should focus on lower-risk follow-up work:

1. update handoff docs to point at this completed rollout state
2. decide whether to commit additional runbook updates for worker duplicate-host
   recovery
3. consider whether first-boot cleanup should be made more explicit or more
   automated
4. only then move on to post-bootstrap cluster services and workload planning

## Working Rule

We may read sibling repositories for context.

We must not edit them without explicit authorization.
