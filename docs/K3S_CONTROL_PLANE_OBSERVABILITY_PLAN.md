# k3s Control-Plane Observability Plan

**Status: ALL PHASES COMPLETE — Phase 4 (scheduler/controller-manager) COMPLETE 2026-04-23.**

See completion summary at the bottom of this document.

---

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

If resuming here for scheduler/controller-manager work, start with:

1. read this file
2. verify `kubelet-cadvisor` Prometheus target is still `up=1`
3. design the authenticated in-cluster collection model for scheduler (`:10259`) and controller-manager (`:10257`)
4. implement as a new proxy component in `kubernetes/platform/observability/`

---

## Completion Summary — Phase 3 (cAdvisor) — 2026-04-22

### What was implemented

**Cluster-side (`kubernetes/platform/observability/kubelet-metrics-proxy/`):**
- Python proxy deployed in `observability` namespace
- ServiceAccount with RBAC: `nodes/list` + `nodes/proxy/get`
- Fetches `/metrics/cadvisor` from all 5 nodes in parallel via Kubernetes API proxy
  (`https://kubernetes.default.svc/api/v1/nodes/{name}/proxy/metrics/cadvisor`)
- Exposed at `GET /cadvisor-metrics` on `kube-state-metrics.hhlab.home.arpa:443` via Traefik ingress
- Response: ~2 MB per scrape, aggregated across all 5 nodes

**Monitoring-side (`nix-pi-private/modules/rpi-box-02.nix`):**
- `extraStaticJobs` entry: job `kubelet-cadvisor`, scheme `https`, path `/cadvisor-metrics`, tlsInsecureSkipVerify true
- Uptime Kuma keyword monitor: `kubelet-cadvisor-proxy` checks `cadvisor_version_info`

### Validation

- `up{job="kubelet-cadvisor"} = 1`
- `count(container_cpu_usage_seconds_total)` = 254 series (all 5 nodes, all containers)

### What was deliberately not implemented

**Raw kubelet `/metrics`:**
k3s bundles the API server aggregator into the kubelet process. The `/metrics` endpoint on
each node returns ~3 MB including API server aggregator metrics. Aggregated across 5 nodes
this is 14 MB per scrape — exceeds Prometheus scrape timeout and provides low marginal
value since kube-state-metrics already covers pod health.

**Scheduler (`:10259`) and controller-manager (`:10257`):**
These listeners are bound to `127.0.0.1` and return `403` without RBAC + bearer tokens.
Accessing them requires an authenticated in-cluster collection approach. Deferred.

---

## Completion Summary — Phase 4 (scheduler/controller-manager) — 2026-04-23

### What was implemented

**k3s flags (`nixos/modules/k3s-common.nix`):**
- `--kube-scheduler-arg=bind-address=0.0.0.0` — expose scheduler on all interfaces
- `--kube-scheduler-arg=authorization-always-allow-paths=/metrics,/healthz,/readyz` — bypass RBAC for metrics
- Same two flags for `--kube-controller-manager-arg`
- Firewall ports 10257 and 10259 opened on all control-plane nodes

**Cluster-side (`kubernetes/platform/observability/control-plane-metrics-proxy/`):**
- Python proxy deployed in `observability` namespace
- ServiceAccount with RBAC: `nodes/list`
- Discovers all control-plane node IPs (label `node-role.kubernetes.io/control-plane`)
- Fetches `/metrics` directly from each node over HTTPS with `ssl.CERT_NONE` (no auth token needed — auth bypassed via `authorization-always-allow-paths`)
- Aggregates in parallel with 15s per-node timeout
- Routes: `/scheduler-metrics` → `:10259`, `/controller-manager-metrics` → `:10257`
- Exposed on `kube-state-metrics.hhlab.home.arpa:443` via Traefik ingress (same host as other proxies)

**Monitoring-side (`nix-pi-private/modules/rpi-box-02.nix`):**
- `extraStaticJobs` entries: `kube-scheduler` and `kube-controller-manager`, 60s interval / 30s timeout
- Uptime Kuma keyword monitors for both endpoints

**nix-services (`services/prometheus/`):**
- Added `scrapeInterval` and `scrapeTimeout` options to `extraStaticJobs` submodule

### Validation

- `up{job="kube-scheduler"} = 1`
- `up{job="kube-controller-manager"} = 1`
- Both scraping from all 3 control-plane nodes in parallel

### Design notes

- Auth bypass via `authorization-always-allow-paths` is safe for homelab: metrics contain no sensitive state,
  and the port is only accessible inside the cluster LAN (firewall allows only cluster nodes, not the internet)
- 60s scrape interval chosen because the proxy aggregates 3 nodes sequentially in the worst case
- `renderObservability` in `flake.nix` was broken (missing `text` field); fixed to use `renderTemplatedKustomize`
