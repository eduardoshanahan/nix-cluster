# Implementation Roadmap

## Phase 1

Build the base cluster platform.

Deliverables:

- repository scaffold
- NixOS flake for Raspberry Pi 4 cluster nodes
- five host configurations
- private override mechanism for homelab-specific values
- SD card preparation and bootstrap runbook

Success criteria:

- all five nodes boot NixOS
- SSH access works reliably
- control-plane nodes form a healthy `k3s` cluster
- worker nodes join cleanly
- cluster survives reboots
- rebuild workflow is repeatable

## Phase 2

Integrate cluster-adjacent platform services.

Likely tasks:

- create DHCP reservations for all cluster nodes on the UCG Max
- add load-balancer strategy
- choose and deploy ingress controller
- integrate TLS/certificate handling
- expose cluster endpoints through existing homelab DNS patterns
- add monitoring visibility to existing tooling

## Phase 3

Prepare for selective workload onboarding.

Likely tasks:

- classify existing services by migration suitability
- define storage classes and persistent volume approach
- define backup expectations for in-cluster state
- choose app delivery model

## First Open Decisions

These are the first decisions that still need operator confirmation:

- exact node names if different from the proposed `cluster-pi-01` to `05`
- whether the existing wildcard certificate private key may be reused by the
  cluster later, or whether the cluster should consume certificates via another
  path
