# Fresh Restart Handoff

## Purpose

This document is the handoff point for the next clean implementation session.

The goal of the next session is to restart the cluster bootstrap from
`cluster-pi-01` using the refactored repository layout and a stricter
single-image workflow.

## Decision

We are restarting the cluster bootstrap from scratch.

That means:

- use one shared bootstrap image for all five SD cards
- configure each node after first boot
- rebuild trust from `cluster-pi-01`
- do not continue mixing old and new node-specific bootstrap artifacts
- treat the current cluster state as disposable learning state

## Why We Are Restarting

The first implementation pass taught us useful things, but the image workflow
was too brittle.

Key reasons for the restart:

- host-specific SD-card iteration was too fragile
- stale artifacts were too easy to confuse with fresh ones
- validation before flashing was not strong enough
- we want a clearer separation between host provisioning and cluster services
- we want a post-boot deploy workflow for future changes

## What Is Already Refactored

The repository has already been moved toward the new structure:

- Raspberry Pi base profile:
  `nixos/profiles/rpi4-base.nix`
- shared `k3s` behavior:
  `nixos/modules/k3s-common.nix`
- validation assertions:
  `nixos/modules/validation.nix`
- flake helpers:
  `validate-cluster-node`
  `deploy-cluster-node`
- workload boundary placeholder:
  `kubernetes/README.md`

## Important Constraint For The Restart

We are being strict:

- we do not want five different bootstrap images
- we want one shared image
- each node should be configured after first boot

The repository refactor improved validation and separation of concerns, but it
has not yet completed that final single-image provisioning model.

That should be the first implementation goal of the next session.

## Cluster Identity And Inventory

### API endpoint

- `cluster-api.<homelab-domain>`

### Nodes

| Node | Role | DHCP reservation | MAC address |
| --- | --- | --- | --- |
| `cluster-pi-01` | control plane | `192.0.2.31` | `aa:bb:cc:dd:ee:ff` |
| `cluster-pi-02` | control plane | `192.0.2.32` | `aa:bb:cc:dd:ee:ff` |
| `cluster-pi-03` | control plane | `192.0.2.33` | `aa:bb:cc:dd:ee:ff` |
| `cluster-pi-04` | worker | `192.0.2.34` | `aa:bb:cc:dd:ee:ff` |
| `cluster-pi-05` | worker | `192.0.2.35` | `aa:bb:cc:dd:ee:ff` |

## Recommended Next Session Sequence

1. Confirm the refactored repo is the intended new baseline.
2. Implement the single shared bootstrap image workflow.
3. Document how node identity and role are applied after first boot.
4. Build the shared bootstrap image.
5. Inspect the generated image contents before flashing.
6. Flash `cluster-pi-01`.
7. Boot only `cluster-pi-01` and verify:
   - SSH access
   - hostname
   - post-boot node configuration flow
   - `k3s server`
   - API endpoint behavior
8. Repeat the same shared-image bootstrap for `cluster-pi-02` through
   `cluster-pi-05`, configuring each node after boot.
9. Only after the cluster is healthy again, move to future service onboarding.

## Rules For The Restart

- keep host provisioning under `nixos/`
- keep future cluster workloads under `kubernetes/`
- validate generated `k3s` units before flashing
- do not return to per-node bootstrap images
- prefer deploys over reflashing once a node has booted successfully

## Related Documents

- `README.md`
- `HOMELAB_AND_CLUSTER_CONTEXT.md`
- `docs/RESTART_PLAN.md`
- `docs/LESSONS_LEARNED.md`
- `docs/NODE_INVENTORY_TEMPLATE.md`
