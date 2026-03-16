# nix-cluster

Declarative NixOS-based Kubernetes cluster work for the homelab Raspberry Pi
fleet.

## Current Status

We are intentionally restarting the implementation workflow after learning that
the first per-node SD-card approach was too brittle.

The cluster shape is still the same:

- five Raspberry Pi 4 nodes with 8 GB RAM each
- NixOS on every node
- `k3s`
- 3 control-plane nodes and 2 workers
- no workload migration yet

What changes now is the provisioning workflow.

## New Direction

The cluster should be built around:

- one known-good Raspberry Pi 4 base image
- node-specific configuration applied after first boot
- minimal per-node differences
- clear separation between Pi host provisioning and services running on the
  cluster
- validation of generated `k3s` units before flashing
- post-boot deploys for most changes instead of repeated reflashing

The goal is to make the cluster easier to understand, safer to iterate on, and
more aligned with good NixOS and homelab practices.

## Start Here

- `HOMELAB_AND_CLUSTER_CONTEXT.md`
- `docs/RESTART_PLAN.md`
- `docs/LESSONS_LEARNED.md`
- `docs/NODE_INVENTORY_TEMPLATE.md`

## Repository Layout

- `flake.nix`: Nix flake entrypoint
- `nixos/modules/`: shared NixOS modules
- `nixos/profiles/`: reusable profiles
- `nixos/hosts/`: public node definitions
- `nixos/hosts/private/`: gitignored environment-specific overrides
- `kubernetes/`: future in-cluster service definitions, kept separate from host
  provisioning
- `docs/`: operator documentation and planning

## Working Rule

We may read from `../nix-pi`, `../nix-services`, and `../synology-services`
for context.

We must not edit those repositories without explicit authorization.
