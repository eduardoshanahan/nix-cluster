# Restart Plan

## Purpose

This document defines the new implementation approach for the Raspberry Pi
cluster after the first bootstrap attempt proved too brittle.

The point of this restart is not to change the cluster goals. The point is to
use a better workflow to reach them.

## Cluster Goal

We still want:

- five Raspberry Pi 4 nodes with 8 GB RAM each
- NixOS on every node
- `k3s`
- three control-plane nodes and two workers
- integration with the existing homelab
- no workload migrations until the platform is stable

## What Changes

We no longer want to rely on a highly individualized per-node image workflow as
the normal way of making progress.

The new workflow should prefer:

1. one known-good Raspberry Pi 4 base image
2. one control-plane role layer
3. one worker role layer
4. minimal per-node identity data
5. validation before flashing
6. post-boot deploys for most follow-up changes

It should also preserve a clean separation between:

- host provisioning for the Raspberry Pis
- services and workloads that run on the cluster

## Target Provisioning Model

### Base image

The base image should only solve hardware bootstrap and shared operating-system
concerns:

- Raspberry Pi 4 boot support
- SSH key access
- NixOS base settings
- networking defaults
- shared admin tooling

The base image should not bake in fragile role-specific behavior unless it is
clearly validated.

### Role overlays

There should be two role-specific layers:

- control plane
- worker

Role modules must make server-only and agent-only `k3s` behavior explicit.

Examples:

- control plane may set `clusterInit`, API TLS SANs, and server-only flags
- workers must never receive server-only flags such as
  `--write-kubeconfig-mode`

### Per-node identity

Per-node configuration should be as small as possible:

- hostname
- node role assignment
- DHCP reservation / expected IP reference
- future labels or taints if needed

Per-node files should not become the main place where cluster behavior lives.

## Host And Service Separation

This repository should keep host concerns separate from cluster workload
concerns.

Host-side concerns include:

- Raspberry Pi boot support
- NixOS base configuration
- SSH access
- networking
- `k3s` installation and node role
- operating-system level validation and deploy workflows

Service-side concerns include:

- Kubernetes manifests
- Helm charts
- application configuration
- ingress resources
- application-level secrets and runtime policy

Those service definitions should live in their own area of the repository and
should not be mixed into the host bootstrap modules.

## Validation Gates

Before we flash any card, we should validate the generated systemd unit and
cluster role assumptions.

At minimum, validation must confirm:

- control-plane nodes generate `k3s server`
- worker nodes generate `k3s agent`
- worker nodes do not contain `--write-kubeconfig-mode`
- control-plane nodes do contain server-only settings where expected
- API endpoint and token are present
- SSH authorized keys are present

These checks should happen before we consider an image ready.

## Deployment Workflow

The long-term workflow should be:

1. flash only for initial bootstrap or true recovery
2. use SSH to reach a booted node
3. use Nix deploys for most changes after first boot

Reflashing should become the exception, not the default.

That means the cluster should move toward a post-boot workflow such as:

- `nixos-rebuild switch --target-host`
- or another reproducible remote deploy path from this repository

## Immediate Next Implementation Steps

1. Refactor profiles into:
   - Raspberry Pi base
   - control-plane role
   - worker role
2. Add validation checks for generated `k3s` units
3. Build fresh role-correct worker images
4. Recover `cluster-pi-04` and `cluster-pi-05`
5. Add a documented post-boot deploy flow
6. Only then continue with ingress, certificates, and workload planning

## Success Criteria For The Restart

The restart is successful when:

- a single base approach boots reliably on the Pis
- role-specific `k3s` behavior is correct by construction
- worker mistakes are caught before flashing
- node recovery does not require guesswork
- most iterative changes happen through deploys rather than repeated SD-card
  image churn
