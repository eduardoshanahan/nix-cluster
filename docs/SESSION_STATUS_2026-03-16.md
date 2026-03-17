# Session Status: 2026-03-16

## Purpose

This document captures the exact state of the cluster work at the end of the
session so the next session can continue cleanly.

## Current Decision

We are being strict about the restart.

The intended model is now:

- one shared Raspberry Pi bootstrap image
- nodes boot that same image
- node identity and role are configured after first boot
- we do not return to per-node bootstrap images

## What Was Completed

### Repository direction

The repository was refactored toward a cleaner structure:

- shared Raspberry Pi base profile
- explicit server/agent behavior separation
- validation module for generated `k3s` behavior
- documented separation between host provisioning and cluster workloads

Relevant files:

- `nixos/profiles/rpi4-base.nix`
- `nixos/profiles/k3s-server.nix`
- `nixos/profiles/k3s-agent.nix`
- `nixos/modules/k3s-common.nix`
- `nixos/modules/validation.nix`
- `kubernetes/README.md`

### Documentation

The docs were updated to reflect the strict restart:

- `README.md`
- `HOMELAB_AND_CLUSTER_CONTEXT.md`
- `docs/RESTART_PLAN.md`
- `docs/LESSONS_LEARNED.md`
- `docs/FRESH_RESTART_HANDOFF.md`

### Validation

The refactored configuration was validated:

- `cluster-pi-01` generates `k3s server`
- `cluster-pi-01` includes `--write-kubeconfig-mode=0644`
- `cluster-pi-04` generates `k3s agent`
- `cluster-pi-04` does not include `--write-kubeconfig-mode=0644`

### Bootstrap image build

A fresh image was built locally on this host via the remote ARM builder and is
available here:

- `result-cluster-pi-01-refactored/sd-image/nixos-image-sd-card-26.05.20260313.c06b4ae-aarch64-linux.img.zst`

That image was then flashed to the SD cards and booted on the Pis.

## Live Cluster State

### Kubernetes view

From `cluster-pi-01`, the cluster currently shows only one node:

- `cluster-pi-01` at `192.0.2.31`

That node is healthy:

- `Ready`
- role `control-plane,etcd`
- core system pods running
- scheduler, controller-manager, and etcd healthy

### Per-Pi reality

Direct checks showed:

- `192.0.2.31` responds as `cluster-pi-01`, `k3s` active
- `192.0.2.32` responds as `cluster-pi-01`, `k3s` active
- `192.0.2.33` responds as `cluster-pi-01`, `k3s` active
- `192.0.2.34` responds as `cluster-pi-01`, `k3s` active
- `192.0.2.35` responds as `cluster-pi-01`, `k3s` activating

So all or nearly all Pis are booting the shared bootstrap image successfully,
but they have not yet been configured into their real node identities.

## Important Interpretation

This is not a broken result. It is the expected consequence of booting the same
shared image everywhere without yet applying the post-boot node-configuration
step.

The missing piece is now very clear:

- we have the shared bootstrap image
- we do not yet have the post-boot process that turns each booted Pi into
  `cluster-pi-01`, `cluster-pi-02`, `cluster-pi-03`, `cluster-pi-04`, and
  `cluster-pi-05`

## Node Inventory

| Node | Intended role | Expected IP | MAC |
| --- | --- | --- | --- |
| `cluster-pi-01` | control plane | `192.0.2.31` | `aa:bb:cc:dd:ee:ff` |
| `cluster-pi-02` | control plane | `192.0.2.32` | `aa:bb:cc:dd:ee:ff` |
| `cluster-pi-03` | control plane | `192.0.2.33` | `aa:bb:cc:dd:ee:ff` |
| `cluster-pi-04` | worker | `192.0.2.34` | `aa:bb:cc:dd:ee:ff` |
| `cluster-pi-05` | worker | `192.0.2.35` | `aa:bb:cc:dd:ee:ff` |

## Immediate Next Steps

Tomorrow's session should focus on the missing post-boot node-configuration
workflow.

Recommended sequence:

1. Define how a booted shared-image Pi becomes a specific node.
   This likely means a documented deploy flow from this repository to a target
   host after first boot.
2. Decide how to identify each live Pi reliably before applying config.
   The current DHCP reservations and MAC inventory are already available.
3. Apply node-specific configuration to `192.0.2.31` first and confirm the
   flow still works cleanly.
4. Apply node-specific configuration to `192.0.2.32` through
   `192.0.2.35`, turning them into their intended identities and roles.
5. Verify the three control-plane nodes form quorum.
6. Verify the two worker nodes join cleanly.

## What Not To Do Next

To stay aligned with the current decision:

- do not go back to per-node bootstrap images
- do not assume identical booted nodes are already correctly configured
- do not treat the current multi-Pi state as a finished cluster

## Working Rule

We may read sibling repositories for context.

We must not edit them without explicit authorization.
