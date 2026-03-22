# Session Status: 2026-03-20

## Purpose

This document captures the state of `nix-cluster` after the repository layout
was refined for the next phase of cluster service work.

The cluster is still considered non-production and may be reshaped freely.
That makes this a good point to lock in cleaner boundaries before adding more
workloads.

## What Changed

The main change in this session was clarifying the in-repo split between:

- Raspberry Pi host infrastructure in `nixos/`
- shared cluster platform services in `kubernetes/platform/`
- operator tooling in `kubernetes/operations/`
- future application workloads in `kubernetes/apps/`

This keeps the same spirit as the broader homelab split between `nix-pi` and
`nix-services`, but without introducing another repository yet.

## Concrete Repository Changes

- moved observability manifests from `kubernetes/observability/` to
  `kubernetes/platform/observability/`
- added `kubernetes/platform/README.md`
- added `kubernetes/apps/README.md`
- updated top-level Kubernetes docs to teach the new structure
- updated the observability render helper in `flake.nix` to use the new path
- added `kubernetes/platform/networking/traefik/` for repo-managed Traefik
- added `kubernetes/platform/networking/metallb/` for bare-metal `LoadBalancer`
  IP management
- moved Headlamp to a `ClusterIP` backend with an `Ingress`
- added a `render-platform` helper for the full platform tree

## Verification Completed

The following repo helpers rendered successfully after the move:

- `nix run .#render-observability`
- `nix run .#render-headlamp`
- `nix run .#render-platform`

That confirms the current platform and operations trees still render cleanly.

## Current Recommended Mental Model

Use these boundaries going forward:

- `nixos/`: node OS config, K3s, firewalling, SSH, deploy helpers, validation
- `kubernetes/platform/`: ingress, observability, certificate automation,
  cluster-wide networking components
- `kubernetes/operations/`: cluster UI and operator-facing admin tools
- `kubernetes/apps/`: migrated homelab applications and app-specific manifests

## Current Platform Direction

Traefik is now the intended cluster ingress controller, managed as a normal
repo-owned workload rather than by re-enabling the bundled K3s addon.

Current placement:

- `kubernetes/platform/networking/traefik/`
- `kubernetes/platform/networking/metallb/`

Current Headlamp access direction:

- `headlamp.<homelab-domain>` should route through cluster Traefik
- TLS now reuses the same homelab wildcard certificate strategy via a
  Kubernetes TLS secret
- HTTP now redirects to HTTPS at the Traefik entrypoint
- Traefik is now intended to sit behind MetalLB on a stable LAN IP instead of
  being tied to a specific node IP
- the current pinned Traefik `LoadBalancer` IP is `192.0.2.36`

## Suggested Follow-Up Sequence

1. Point Pi-hole ingress hostnames at `192.0.2.36`
2. Keep new cluster apps behind Traefik using standard Kubernetes `Ingress`
3. Reuse the homelab wildcard TLS secret for additional `*.<homelab-domain>`
   ingresses where appropriate
4. Revisit cert-manager only if in-cluster certificate lifecycle becomes worth
   the added complexity

## Working Rule

We may read sibling repositories for context.

We must not edit them without explicit authorization.
