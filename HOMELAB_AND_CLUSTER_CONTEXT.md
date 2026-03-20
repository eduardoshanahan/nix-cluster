# Homelab And Kubernetes Cluster Context

This repository (`nix-cluster`) is for designing and implementing a new
Kubernetes cluster that will integrate cleanly with the existing homelab.

The current homelab is split across three sibling repositories:

- `../nix-pi`: Raspberry Pi host provisioning, NixOS images, bootstrap, and
  host-level lifecycle management.
- `../nix-services`: service definitions, service policy, and NixOS-managed
  Docker Compose workloads for the Raspberry Pi fleet.
- `../synology-services`: reproducible Docker Compose deployments and runbooks
  for the Synology NAS host (`hhnas4`).

## Current Homelab Shape

Based on the current documentation in those repositories:

- The environment already uses NixOS on Raspberry Pi hardware.
- Host provisioning and hardware concerns are intentionally separated from
  service definitions.
- Existing Raspberry Pi services are generally deployed through NixOS modules
  and managed declaratively.
- The Synology NAS hosts storage-heavy and shared infrastructure services.

The current homelab includes, among other things:

- Raspberry Pi based services such as Traefik, monitoring/logging components,
  Excalidraw, D2, OwnTracks Recorder, SMTP relay, and other NixOS-managed
  workloads documented in `nix-pi` and `nix-services`.
- Synology-hosted services such as Gitea, Jellyfin, Outline, Paperless,
  shared databases, Redis, Tika, Gotenberg, Promtail, and related support
  services documented in `synology-services`.

## New Cluster Goal

We want to build a Kubernetes cluster in this repository with these starting
assumptions:

- Hardware target: five Raspberry Pi 4 nodes
- Memory per node: 8 GB RAM
- Operating system target: NixOS on all cluster nodes
- Primary objective: integrate the new cluster with the existing homelab
- Operator goal: follow best practices and keep the design understandable for
  someone new to Kubernetes
- Immediate scope: get the cluster working correctly before migrating any
  existing workloads

This means the work in `nix-cluster` should favor:

- clear separation of responsibilities
- incremental rollout and low-risk changes
- NixOS-first, declarative infrastructure and operations
- ARM64-friendly tooling
- reproducible, declarative configuration
- simple operations and recovery procedures
- compatibility with existing homelab networking, storage, DNS, ingress,
  logging, monitoring, identity, and backup patterns where appropriate

## Current Restart Direction

We are intentionally restarting the implementation workflow after learning from
the first bootstrap attempt.

The cluster goal has not changed. We still want a healthy, well-understood
Kubernetes platform on NixOS before migrating any existing services.

What is changing is the provisioning model.

The new direction is to favor:

- one known-good Raspberry Pi 4 base image
- node-specific configuration applied after first boot
- minimal per-node identity data
- explicit separation between host provisioning and service definitions
- validation of generated systemd units before flashing
- post-boot deploys for most follow-up changes

That platform should still, where appropriate:

- reuse homelab services that already exist outside the cluster
- integrate with existing operational tooling such as Uptime Kuma
- consume shared infrastructure such as external Postgres when that is the
  better fit
- align with the same certificate and TLS approach already used in the homelab

This remains a best-practice-oriented homelab cluster effort, which means
reversible steps, explicit validation, and keeping the operational model
understandable for someone who is still learning Kubernetes.

That includes keeping a clean boundary between:

- the Raspberry Pi hosts and their operating-system configuration
- the shared cluster platform services that make Kubernetes usable
- the applications and workloads that will eventually run on top of that

## Repository Working Rule

While working on the cluster, we may read from the sibling repositories
(`../nix-pi`, `../nix-services`, and `../synology-services`) for context and
integration planning.

We must not edit those repositories without explicit authorization.
