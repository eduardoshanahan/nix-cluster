# nix-cluster

Declarative NixOS-based Kubernetes cluster for the homelab Raspberry Pi fleet.

## Goal

This repository is for building a new Kubernetes cluster on five Raspberry Pi 4
nodes with 8 GB RAM each.

The immediate goal is to get the cluster working correctly on NixOS before
migrating any existing workloads.

## First-phase Principles

- NixOS on every node
- As much declarative configuration as practical
- Lightweight Kubernetes distribution suitable for ARM64 homelab hardware
- Reuse existing homelab services where that is the better operational fit
- Keep migrations out of scope until the platform is stable

## Starting Architecture

The initial scaffold assumes:

- `k3s` as the Kubernetes distribution
- 3 control-plane nodes
- 2 worker nodes
- external integrations with existing homelab services where relevant
- incremental adoption of ingress, certificates, storage, and monitoring

More detail lives in:

- `HOMELAB_AND_CLUSTER_CONTEXT.md`
- `docs/ARCHITECTURE.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/SD_CARD_AND_BOOTSTRAP_RUNBOOK.md`

## Repository Layout

- `flake.nix`: Nix flake entrypoint
- `nixos/modules/`: shared NixOS modules
- `nixos/profiles/`: reusable profiles
- `nixos/hosts/`: public node definitions
- `nixos/hosts/private/`: gitignored environment-specific overrides
- `docs/`: architecture and operator documentation

## Build Targets

Planned outputs:

- one generic Raspberry Pi 4 SD image profile for Kubernetes nodes
- five host-specific NixOS configurations for the cluster nodes

## Working Rule

We may read from `../nix-pi`, `../nix-services`, and `../synology-services`
for context.

We must not edit those repositories without explicit authorization.
