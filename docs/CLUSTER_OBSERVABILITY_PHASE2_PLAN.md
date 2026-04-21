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

## Current Baseline As Of 2026-03-21

The original Phase 2 plan was written before the first Kubernetes-aware
observability slice was implemented.

That baseline has now changed.

Already in place:

- `kube-state-metrics` is deployed from `nix-cluster`
- the metrics endpoint is exposed through Traefik ingress at
  `https://kube-state-metrics.<homelab-domain>:443/metrics`
- Prometheus on `rpi-box-02` scrapes that endpoint
- Grafana content for Kubernetes overview now exists in `nix-services`
- initial alert rules for Kubernetes state also exist in `nix-services`

This means the next observability phase should not restart from "should we add
`kube-state-metrics`?".

It should start from "the first Kubernetes-aware metrics path exists; what is
the next highest-value expansion beyond that foundation?".

## Initial `k3s` Investigation Findings As Of 2026-03-21

The first control-plane investigation for this phase already established some
important constraints from the live cluster.

Observed on `cluster-pi-01`:

- scheduler metrics listener exists on `127.0.0.1:10259`
- controller-manager metrics listener exists on `127.0.0.1:10257`
- kubelet listens on `:10250`
- Kubernetes API listens on `:6443`

Observed response shape:

- `https://127.0.0.1:10257/metrics` returns `403`
- `https://127.0.0.1:10259/metrics` returns `403`
- `https://127.0.0.1:10250/metrics` returns `401`
- `https://127.0.0.1:6443/metrics` returns `401`

Implications:

- there is a real control-plane telemetry surface in `k3s`
- it is not currently exposed in a way that the external Prometheus host on
  `rpi-box-02` can scrape directly without extra design work
- raw direct scraping from the monitoring host should not be treated as the
  next easy step
- the next implementation pass should focus on authenticated access design or
  an in-cluster collection path, not on opening more host ports casually

Follow-on design document:

- `docs/K3S_CONTROL_PLANE_OBSERVABILITY_PLAN.md`

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

This was the clearest first candidate for Kubernetes-aware state telemetry, and
it is now the implemented foundation.

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

### Step 1. Keep `kube-state-metrics` as the Phase 2 foundation

This remains the right anchor for Kubernetes state visibility, but it should be
treated as completed groundwork rather than future planning.

### Step 2. Keep scraping it from the existing Prometheus host

The monitoring hub on `rpi-box-02` should remain the central observability
point unless a future architectural change is made deliberately.

That means:

- cluster-native metrics are produced in the cluster
- Prometheus on `rpi-box-02` scrapes them
- Grafana on `rpi-box-02` renders them

### Step 3. Expand beyond basic Kubernetes state visibility

The first cluster-focused dashboard layer now exists.

The next pass should focus on the gaps that remain after `kube-state-metrics`,
initial dashboards, and first-pass alerts are already live.

Good initial dashboard themes:

- cluster overview
- node readiness and pressure
- pod health and restart activity
- workload status by namespace

### Step 4. Add or refine alert candidates only after signal quality is proven

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

These should be answered at the start of the next observability session:

1. Is the current `kube-state-metrics` plus ingress path the long-term exposure
   model we want to keep?
   It is the current working implementation, but future tightening or a more
   direct scrape model may still be worth evaluating.

2. Which control-plane signals matter enough to add next?
   The biggest remaining gap is no longer basic workload state. It is deeper
   visibility into API-server, kubelet, and `k3s` control-plane health where
   that is realistically available.

3. How much `k3s` control-plane telemetry is realistically available and worth
   the complexity in this environment?

4. Should cluster alerting be added in the same pass, or only after dashboards
   and current signals are validated in practice?

## Proposed Execution Order

1. Confirm the current Phase 1 and early Phase 2 foundation is still healthy.
2. Treat `kube-state-metrics`, Prometheus scraping, and current dashboards as
   the established baseline.
3. Treat the initial `k3s` endpoint investigation in this document as the
   starting constraint set, not as an unanswered question.
4. Decide on one safe collection model for control-plane metrics before adding
   more telemetry:
   - authenticated in-cluster scraper
   - controlled proxy path
   - or explicit deferral if the complexity is not worth it yet
5. Only after that decision, add API-server, kubelet, or other cluster-runtime
   metrics.
6. Extend dashboards only where the new signals materially improve operator
   understanding.
7. Refine alert rules once the added signals prove useful and low-noise.

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
2. begin by validating the existing Phase 1 and early Phase 2 foundation is
   still healthy
3. then investigate the next highest-value telemetry gap after
   `kube-state-metrics`, starting with realistic `k3s` control-plane signals
4. do not assume those signals are directly scrapeable from `rpi-box-02`
   without an authenticated design
