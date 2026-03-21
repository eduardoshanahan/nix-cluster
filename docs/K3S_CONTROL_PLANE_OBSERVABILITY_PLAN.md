# k3s Control-Plane Observability Plan

## Purpose

This document defines the next implementation slice after the initial
`kube-state-metrics` rollout.

The problem is no longer "how do we get basic Kubernetes state into the homelab
monitoring stack?".

That is already solved by:

- `kube-state-metrics` in `nix-cluster`
- Prometheus scraping from `rpi-box-02`
- Grafana dashboards and first-pass alerting in sibling repos

The next gap is deeper visibility into the live `k3s` control plane.

## What We Learned From The Live Cluster

Direct inspection on `cluster-pi-01` showed:

- scheduler metrics listener on `127.0.0.1:10259`
- controller-manager metrics listener on `127.0.0.1:10257`
- kubelet metrics listener on `:10250`
- Kubernetes API metrics listener on `:6443`

Current access behavior:

- scheduler `/metrics` returns `403`
- controller-manager `/metrics` returns `403`
- kubelet `/metrics` returns `401`
- API server `/metrics` returns `401`

That means the raw telemetry surface exists, but it is not directly usable from
the external Prometheus host without extra authentication and exposure design.

## Boundary To Respect

Keep these responsibilities explicit:

- `nix-cluster`
  - cluster-side collection design
  - any in-cluster proxy, scraper, RBAC, or exposure model
- `nix-pi`
  - Prometheus scrape inventory on `rpi-box-02`
- `nix-services`
  - Prometheus job model extensions, dashboards, and alert rules if needed

Do not solve a cluster-side auth/exposure problem by silently stuffing more
host-specific exceptions into `nix-pi`.

## Recommended Direction

Use an authenticated in-cluster collection model.

Current prototype in this repo:

- `kubernetes/platform/observability/apiserver-metrics-proxy/`
- deployed as an internal `ClusterIP` service in `observability`
- fetches API server metrics from `https://kubernetes.default.svc/metrics`
- proves the cluster-side auth and collection pattern for the first target

Preferred shape:

1. keep raw control-plane endpoints private
2. collect or proxy the needed metrics from inside the cluster or node context
3. expose only the intentionally designed scrape target to the external
   monitoring host

This is preferred over opening additional host ports because:

- the live endpoints already show auth restrictions
- scheduler and controller-manager listeners are localhost-bound
- kubelet and API server endpoints should not be exposed casually on the LAN
- it keeps the security and operator story cleaner

## Options Considered

### Option A. Scrape raw `k3s` endpoints directly from `rpi-box-02`

Not recommended.

Why:

- localhost-bound endpoints are not reachable externally
- authenticated endpoints would require credentials and transport design anyway
- it would tempt broad port exposure on cluster nodes

### Option B. Add a controlled in-cluster proxy or exporter

Recommended first implementation direction.

Possible shapes:

- a small in-cluster proxy that authenticates to selected endpoints
- a DaemonSet or node-local collector for kubelet-facing signals
- a cluster-local collector for API-server or control-plane metrics

Why this is the best next step:

- it fits the ownership of `nix-cluster`
- it keeps auth and endpoint handling inside the cluster boundary
- it gives `rpi-box-02` one explicit scrape target instead of many ad hoc ones

### Option C. Defer control-plane metrics for now

Valid fallback if the complexity turns out to be too high for the current
homelab stage.

If we defer, that should be an explicit decision, not an accidental stall.

## Recommended First Slice

The first implementation slice should be a design-and-proof phase, not a large
multi-repo rollout.

Concretely:

1. choose one control-plane signal family to target first
   - API server metrics
   - kubelet metrics
   - scheduler/controller-manager metrics
2. choose one cluster-side authenticated collection pattern
3. prove that pattern in `nix-cluster`
4. only then extend sibling repos for external scrape, dashboards, or alerts

## Recommended Target Order

1. API server metrics
2. kubelet metrics
3. scheduler and controller-manager metrics

Why this order:

- API server health is high-value and conceptually central
- kubelet metrics are useful but node-oriented and may require more care
- scheduler/controller-manager metrics are clearly present, but the localhost
  binding and `403` behavior make them the least straightforward first target

## Definition Of Done For The Next Slice

This phase should count as complete only when:

1. one control-plane metric family is intentionally selected
2. its collection/authentication path is documented
3. the cluster-side manifests or configuration live in `nix-cluster`
4. the external Prometheus integration path is clear, even if implemented in a
   later sibling-repo change
5. the operator workflow is simpler than "remember a pile of one-off curl
   commands"

## Immediate Next Session Prompt

If resuming from here, start with:

1. read this file
2. verify the existing `kube-state-metrics` path is still healthy
3. choose the first control-plane metric family to target
4. prototype the cluster-side authenticated collection design in `nix-cluster`
