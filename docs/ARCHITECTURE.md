# Architecture

## Scope

This document defines the initial architecture for the first working version of
the homelab Kubernetes cluster.

The objective of this phase is platform readiness, not workload migration.

## Initial Decisions

### Kubernetes distribution

The initial implementation uses `k3s`.

Reasoning:

- mature and common for small ARM64 clusters
- supported on NixOS
- lighter operational footprint than a more custom kubeadm stack
- good fit for five Raspberry Pi 4 nodes
- simpler bootstrap path for a first Kubernetes platform

### Node roles

The first cluster layout is:

- `cluster-pi-01`: control plane
- `cluster-pi-02`: control plane
- `cluster-pi-03`: control plane
- `cluster-pi-04`: worker
- `cluster-pi-05`: worker

This gives us:

- quorum-safe control plane placement
- room to isolate some workloads onto workers later
- a path to node maintenance without collapsing the whole cluster

### Operating system

All nodes run NixOS and should be managed declaratively from this repository.

### Networking

The initial model assumes:

- one stable IP address per node
- DHCP reservations managed by the UCG Max
- a stable Kubernetes API endpoint defined in private config

The scaffold supports declaring the API endpoint separately from any individual
node name so we can later move to a VIP or DNS-based control plane endpoint.

For this homelab, DHCP reservations are the preferred model over fully static
addressing inside NixOS. That keeps network ownership centralized while still
providing stable node addresses.

### Ingress and load balancing

Phase 1 focuses on a healthy cluster first.

We do not need to finalize the long-term ingress controller or service load
balancer before the control plane is operational. The likely direction is:

- `MetalLB` for `LoadBalancer` services inside the homelab LAN
- either `Traefik` or `ingress-nginx` as the main ingress controller

Because the wider homelab already uses Traefik and shared certificates, Traefik
is a strong candidate, but that does not need to block node bootstrap.

### Certificates and TLS

The cluster should align with the existing homelab TLS approach.

That likely means one of these models later:

- reuse the existing wildcard certificate material for ingress termination
- or issue cluster-facing certs from the same internal CA / trust model

The current scaffold treats certificate reuse as a required integration goal,
but does not hardcode certificate material into the repository.

### Secrets

No secrets should be committed here.

Bootstrap credentials, cluster tokens, and future application secrets should be
provided through private overrides and later moved to a stronger secret
management path once the cluster base is stable.

### External integrations

Where useful, the cluster should reuse services that already exist outside it,
for example:

- Uptime Kuma for external health checks
- external Postgres for selected workloads
- existing DNS and TLS arrangements
- existing logging and monitoring systems where practical

## What Is Deliberately Deferred

The following are intentionally not locked down in the first scaffold:

- workload migrations
- persistent storage strategy for stateful in-cluster apps
- final ingress controller choice
- final in-cluster secret management pattern
- GitOps tooling

Those decisions are easier and safer once the cluster nodes are consistently
booting, joining, and surviving rebuilds.
