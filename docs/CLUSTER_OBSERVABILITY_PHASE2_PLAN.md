# Cluster Observability Phase 2 Plan

## Purpose

This document defines the second observability phase for the Raspberry Pi
Kubernetes cluster.

Phase 2 starts only after Phase 1 is complete and stable.

Phase 2 adds Kubernetes-aware telemetry so the homelab can answer not just
"are the cluster machines healthy?" but also "is Kubernetes itself healthy?"

## Goal

Add cluster-aware visibility for Kubernetes state, control-plane health, and
workload condition, while fitting cleanly into the existing homelab monitoring
stack.

At the end of Phase 2, the homelab monitoring view should answer:

- are Kubernetes nodes ready?
- are pods failing, restarting, or stuck?
- is the control plane healthy?
- what is the state of workloads by namespace?

## Scope

Included in scope:

- Kubernetes-native telemetry sources
- Prometheus scraping of cluster-aware metrics
- Grafana dashboards for cluster state
- alerting candidates for cluster health

Explicitly out of scope for the first implementation pass:

- deep application-specific dashboards for every future workload
- full SRE-style SLO engineering
- broad log analytics redesign

## Why This Is A Separate Phase

Phase 1 gives host-level observability with low complexity.

Phase 2 is different because it introduces Kubernetes-specific concepts and
tooling, such as:

- cluster state exporters
- API-server or kubelet metrics
- namespace and workload semantics
- cluster-specific dashboard design

This work should happen only after the underlying cluster is stable and basic
host monitoring is already in place.

## Desired End State

The monitoring stack should eventually expose at least these categories:

### 1. Node readiness

- which Kubernetes nodes are `Ready`
- which nodes are `NotReady`
- when node readiness changed

### 2. Pod health

- failing pods
- crash loops
- restart counts
- pending pods
- unschedulable states

### 3. Workload state

- deployments not fully available
- daemonsets not fully scheduled
- statefulsets not fully ready
- per-namespace workload inventory

### 4. Control-plane health

- API server reachable and healthy
- important control-plane metrics available
- k3s control-plane behavior visible at a useful level

## Candidate Data Sources

These are the most likely building blocks.

### A. `kube-state-metrics`

This is the clearest first candidate for Kubernetes-aware state telemetry.

Why:

- exposes node, pod, deployment, daemonset, and statefulset state
- works well with Prometheus and Grafana
- directly supports many of the questions we care about

Likely value:

- node readiness
- pod phase
- restart insight
- deployment availability
- namespace-level workload views

### B. Kubernetes API server and kubelet metrics

These can provide deeper control-plane and node-runtime insight.

Potential value:

- API server health and request behavior
- kubelet or runtime-side operational signals

This area needs more care because:

- metric exposure details vary by platform and configuration
- `k3s` differs from a larger upstream Kubernetes deployment
- security and scrape access need thought

### C. `metrics-server`

This is optional and should not be assumed to replace Prometheus-style
monitoring.

Possible value:

- lightweight resource metrics used inside Kubernetes

But note:

- `metrics-server` is not the same thing as a Prometheus monitoring pipeline
- it may be useful later, but it should not be the first observability anchor

## Recommended Technical Direction

### Packaging decision

For this repository, cluster workloads should be organized with:

- `Kustomize` as the top-level composition model under `kubernetes/`
- selective `Helm` usage for upstream third-party applications
- plain YAML for repo-owned glue resources such as namespaces and future
  ingress or policy objects

Phase 2 should establish that pattern under `kubernetes/platform/` rather than
introducing a one-off deployment style.

### Step 1. Start with `kube-state-metrics`

This is the best first step for Kubernetes-aware visibility.

It is likely to give the largest value-to-complexity ratio.

### Step 2. Scrape it from the existing Prometheus host

The monitoring hub on `rpi-box-02` should remain the central observability
point unless a future architectural change is made deliberately.

That means:

- cluster-native metrics are produced in the cluster
- Prometheus on `rpi-box-02` scrapes them
- Grafana on `rpi-box-02` renders them

### Step 3. Add cluster-focused Grafana dashboards

This phase likely needs new dashboard content, because the existing host-health
dashboards are not enough for Kubernetes state.

Good initial dashboard themes:

- cluster overview
- node readiness and pressure
- pod health and restart activity
- workload status by namespace

### Step 4. Add alert candidates only after signal quality is proven

Once dashboards are trustworthy, alerting can be considered for:

- node not ready
- pods crash looping
- deployment replicas unavailable
- API endpoint unavailable

## Repository Boundaries

### `nix-cluster`

Owns:

- cluster-native telemetry components running in or for the cluster
- exposure of Kubernetes metrics endpoints
- any manifests or declarative cluster-side setup needed for telemetry

### `nix-pi`

Owns:

- Prometheus scrape inventory on `rpi-box-02`
- alert routing or host-level monitoring integration on the monitoring node

### `nix-services`

Owns:

- Grafana dashboard provisioning
- Prometheus module behavior, if new scrape job types or dashboard expectations
  need to be codified there

## Open Design Questions

These should be answered at the start of the Phase 2 session:

1. Where should `kube-state-metrics` be declared?
   Most likely in `nix-cluster`, because it belongs to cluster telemetry.

2. How should Prometheus on `rpi-box-02` reach cluster-native metrics?
   This depends on whether those endpoints are exposed by service, ingress, or
   some other controlled path.

3. How much `k3s` control-plane telemetry is realistically available and worth
   the complexity in this environment?

4. Should cluster alerting be added in the same pass, or only after dashboards
   are stable?

## Proposed Execution Order

1. Finish and stabilize Phase 1.
2. Establish the `kubernetes/` workload packaging pattern for future services.
3. Investigate the exact `k3s`-compatible telemetry surface.
4. Add `kube-state-metrics` or equivalent cluster-state exporter.
5. Add Prometheus scrape targets on the monitoring host.
6. Build Grafana dashboards for cluster-aware visibility.
7. Evaluate alert rules once the metrics prove useful.

## Validation Gates

### Cluster-side validation

- cluster-native telemetry component deploys cleanly
- metrics endpoint is reachable and stable
- telemetry survives node restarts and cluster restarts

### Monitoring-side validation

- Prometheus scrapes cluster-aware targets successfully
- Grafana renders meaningful cluster state
- telemetry answers real operational questions, not just theoretical ones

## Risks And Notes

### 1. Avoid overbuilding too early

This is a homelab cluster, not a large production estate.

The goal is useful visibility, not maximal monitoring complexity.

### 2. `k3s` specifics matter

Some standard Kubernetes guidance assumes a more conventional upstream
deployment. We should verify assumptions against `k3s` rather than importing
tooling blindly.

### 3. Dashboard quality matters more than metric quantity

A smaller set of accurate, comprehensible cluster dashboards will be more
valuable than a large pile of partially understood panels.

## Fresh Session Start Prompt

If starting a new session for this phase, the next work should be framed as:

1. use this document as the planning baseline
2. begin by validating the Phase 1 foundation is still healthy
3. then investigate the lowest-complexity Kubernetes-native telemetry path,
   starting with `kube-state-metrics`
