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

## Verification Completed

The following repo helpers rendered successfully after the move:

- `nix run .#render-observability`
- `nix run .#render-headlamp`

That confirms the current platform and operations trees still render cleanly.

## Current Recommended Mental Model

Use these boundaries going forward:

- `nixos/`: node OS config, K3s, firewalling, SSH, deploy helpers, validation
- `kubernetes/platform/`: ingress, observability, certificate automation,
  cluster-wide networking components
- `kubernetes/operations/`: cluster UI and operator-facing admin tools
- `kubernetes/apps/`: migrated homelab applications and app-specific manifests

## Recommended Next Step

The next logical platform addition is Traefik, managed as a normal cluster
workload rather than re-enabling the bundled K3s Traefik addon.

Recommended placement:

- `kubernetes/platform/networking/traefik/`

Reasoning:

- the rest of the homelab already uses Traefik
- the cluster can stay consistent with the existing operator mental model
- keeping it repo-managed preserves the clean boundary already established in
  `nix-cluster`

## Suggested Follow-Up Sequence

1. Scaffold the Traefik area under `kubernetes/platform/`
2. Decide whether the platform grouping should be `networking/traefik/` or
   `ingress/traefik/`
3. Start with standard Kubernetes `Ingress` resources before adding
   Traefik-specific CRDs
4. Keep K3s packaged `traefik` disabled
5. Revisit MetalLB and cert-manager after Traefik is in place

## Working Rule

We may read sibling repositories for context.

We must not edit them without explicit authorization.
