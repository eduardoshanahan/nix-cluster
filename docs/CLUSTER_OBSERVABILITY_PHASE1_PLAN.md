# Cluster Observability Phase 1 Plan

## Purpose

This document defines the first observability phase for the Raspberry Pi
Kubernetes cluster.

Phase 1 is intentionally limited to:

- basic cluster availability checks in Uptime Kuma
- cluster-node host health in Prometheus and Grafana

This phase does **not** include Kubernetes-aware telemetry such as pod state,
workload state, restart counts, or namespace-level visibility.

## Goal

Create a single homelab monitoring view where the cluster appears alongside the
existing `nix-pi`, `nix-services`, and `synology-services` estate.

At the end of Phase 1, the homelab monitoring stack should answer:

- is the cluster reachable?
- are the cluster nodes up?
- are cluster nodes under CPU, memory, disk, or temperature pressure?

## Scope

Included in scope:

- Uptime Kuma checks for cluster reachability
- host metrics from cluster nodes via Prometheus-friendly exporters
- Grafana visibility for cluster node CPU, memory, disk, load, and temperature
- Prometheus scrape integration on the existing monitoring host

Explicitly out of scope:

- Kubernetes-native telemetry
- pod / deployment / namespace metrics
- application dashboards running inside the cluster
- Dozzle integration
- Homepage cards for cluster components

## Current Architecture

The current homelab monitoring hub already exists on `rpi-box-02` in
`nix-pi`.

Today that host already runs:

- Uptime Kuma
- Prometheus
- Grafana
- Alertmanager
- Homepage

Current observations:

- Kuma desired monitors are declared in `nix-pi`
- Prometheus scrape targets are declared in `nix-pi`
- Grafana dashboards are provisioned from `nix-services`
- `nix-cluster` does not yet expose host metrics or cluster-specific metrics

## Desired End State

### 1. Kuma coverage

Kuma should show basic cluster reachability with monitors such as:

- Kubernetes API endpoint on `cluster-api.<homelab-domain>:6443`
- SSH reachability for each cluster node
- optional additional TCP or HTTP checks only if they are safe and stable

This layer answers:

- can we reach the cluster?
- which node is down, if any?

### 2. Prometheus coverage

Prometheus should scrape host metrics from all five cluster nodes.

Target outcome:

- `cluster-pi-01`
- `cluster-pi-02`
- `cluster-pi-03`
- `cluster-pi-04`
- `cluster-pi-05`

The intended model is to make these nodes look like any other monitored
homelab host from the perspective of Prometheus.

### 3. Grafana coverage

Grafana should include cluster nodes in the existing host-health views, or in a
small cluster-specific host dashboard if clearer.

Metrics of interest:

- node up/down
- CPU usage
- memory available
- root filesystem usage
- load average
- temperature

## Recommended Technical Approach

### A. Add a host metrics exporter to cluster nodes

The simplest fit with the current homelab stack is to expose node-level metrics
from each cluster Pi.

The strongest candidate is:

- Prometheus `node_exporter`

Why:

- the existing Prometheus configuration model already expects node targets
- the existing Grafana dashboards already use node-exporter-style metrics
- this gives immediate value with minimal conceptual complexity

### B. Add minimal firewall support in `nix-cluster`

Cluster nodes will need to expose the chosen metrics port to the monitoring
stack.

This should be narrowly scoped:

- only the metrics endpoint(s) needed
- preferably only reachable from the monitoring environment if practical

### C. Extend Prometheus scrape targets in `nix-pi`

On `rpi-box-02`, Prometheus should learn the cluster node targets.

This is most naturally owned by `nix-pi`, because that repo already owns the
monitoring host and its scrape inventory.

### D. Extend Kuma desired monitors in `nix-pi`

Kuma monitor definitions should also be updated on `rpi-box-02`.

Likely monitor types:

- TCP monitor for `cluster-api.<homelab-domain>:6443`
- port monitor for SSH on each cluster node

If later desired, node-exporter `/metrics` reachability could also be checked,
but that is optional and may be redundant once Prometheus scrape health exists.

## Repository Boundaries

### `nix-cluster`

Owns:

- exposing host metrics on cluster nodes
- cluster-node firewall allowances
- any cluster-side labels or host metadata needed for scraping

Does not own:

- Grafana dashboard provisioning for the homelab monitoring stack
- Prometheus scrape inventory on `rpi-box-02`
- Kuma monitor inventory on `rpi-box-02`

### `nix-pi`

Owns:

- Prometheus scrape target additions on `rpi-box-02`
- Kuma monitor additions on `rpi-box-02`
- any host DNS or metrics-target naming conventions used by the monitoring hub

### `nix-services`

Owns:

- Grafana dashboard definitions and Prometheus module behavior, if changes are
  needed there

Expected impact here should be small for Phase 1, because the current stack
already supports node-style scraping.

## Proposed Execution Order

1. Decide the exact metrics exposure model for cluster nodes.
2. Implement host metrics export in `nix-cluster`.
3. Verify metrics endpoints directly from the LAN.
4. Add Prometheus scrape targets on `rpi-box-02` in `nix-pi`.
5. Confirm Prometheus target health.
6. Add Kuma monitors in `nix-pi`.
7. Verify Grafana shows useful cluster-node host health.

## Validation Gates

### Cluster-side validation

- each cluster node exposes the chosen metrics endpoint
- endpoint responds reliably after reboot
- firewall rules are correct

### Monitoring-side validation

- Prometheus shows all cluster targets as `up`
- Grafana panels render cluster nodes alongside existing homelab nodes
- Kuma reports API endpoint and SSH reachability correctly

## Risks And Notes

### 1. Keep Phase 1 intentionally simple

This phase should avoid prematurely adding Kubernetes-native tooling.

The point here is to get fast, dependable visibility using the monitoring stack
that already exists.

### 2. Metrics exposure should stay conservative

Opening metrics ports on cluster nodes should be done thoughtfully.

The cluster is internal-only, but that still does not mean every endpoint
should be broadly reachable without reason.

### 3. Temperature metrics may vary by platform details

The existing dashboards expect standard node-exporter-style host metrics.
Temperature data may need a quick reality check on the Pi cluster nodes.

## Fresh Session Start Prompt

If starting a new session for this phase, the next work should be framed as:

1. implement Phase 1 cluster observability from this document
2. start with cluster-side host metrics exposure in `nix-cluster`
3. only then update `nix-pi` monitoring targets and Kuma monitors

