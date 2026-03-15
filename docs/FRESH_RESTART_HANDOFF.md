# Fresh Restart Handoff

## Purpose

This document is the handoff point for the next clean implementation session.

The goal of the next session is to restart the cluster bootstrap from
`cluster-node-01` using the refactored repository layout and a cleaner workflow.

## Decision

We are restarting the cluster bootstrap from scratch.

That means:

- reflash all five SD cards
- rebuild trust from `cluster-node-01`
- do not continue mixing old and new bootstrap artifacts
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
- control-plane role profile:
  `nixos/profiles/k3s-server.nix`
- worker role profile:
  `nixos/profiles/k3s-agent.nix`
- shared `k3s` behavior:
  `nixos/modules/k3s-common.nix`
- validation assertions:
  `nixos/modules/validation.nix`
- flake helpers:
  `validate-cluster-node`
  `deploy-cluster-node`
- workload boundary placeholder:
  `kubernetes/README.md`

## Important Verified State

The refactored configuration now generates the correct role-specific `k3s`
commands.

Verified:

- `cluster-node-01` generates `k3s server`
- `cluster-node-01` includes `--write-kubeconfig-mode=0644`
- `cluster-node-04` generates `k3s agent`
- `cluster-node-04` does not include `--write-kubeconfig-mode=0644`

The new validation helper was also run successfully for:

- `cluster-node-01`
- `cluster-node-04`

## Cluster Identity And Inventory

### API endpoint

- `cluster-api.<homelab-domain>`

### Nodes

| Node | Role | DHCP reservation | MAC address |
| --- | --- | --- | --- |
| `cluster-node-01` | control plane | `192.0.2.31` | `aa:bb:cc:dd:ee:ff` |
| `cluster-node-02` | control plane | `192.0.2.32` | `aa:bb:cc:dd:ee:ff` |
| `cluster-node-03` | control plane | `192.0.2.33` | `aa:bb:cc:dd:ee:ff` |
| `cluster-node-04` | worker | `192.0.2.34` | `aa:bb:cc:dd:ee:ff` |
| `cluster-node-05` | worker | `192.0.2.35` | `aa:bb:cc:dd:ee:ff` |

## Recommended Next Session Sequence

1. Confirm the refactored repo is the intended new baseline.
2. Build a fresh `cluster-node-01` SD image from the refactored layout.
3. Inspect the generated image contents before flashing.
4. Flash `cluster-node-01`.
5. Boot only `cluster-node-01` and verify:
   - SSH access
   - hostname
   - `k3s server`
   - API endpoint behavior
6. Build and flash `cluster-node-02`.
7. Build and flash `cluster-node-03`.
8. Verify healthy three-node control-plane quorum.
9. Build and flash `cluster-node-04`.
10. Build and flash `cluster-node-05`.
11. Only after the cluster is healthy again, move to post-boot deploy workflow
    improvements and future service onboarding.

## Rules For The Restart

- keep host provisioning under `nixos/`
- keep future cluster workloads under `kubernetes/`
- validate generated `k3s` units before flashing
- prefer fresh output names when debugging artifacts
- prefer deploys over reflashing once a node has booted successfully

## Related Documents

- `README.md`
- `HOMELAB_AND_CLUSTER_CONTEXT.md`
- `docs/RESTART_PLAN.md`
- `docs/LESSONS_LEARNED.md`
- `docs/NODE_INVENTORY_TEMPLATE.md`
