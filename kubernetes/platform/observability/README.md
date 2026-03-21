# Observability Workloads

This directory holds cluster-side observability components.

Current components:

- `kube-state-metrics` for Kubernetes object state telemetry
- `apiserver-metrics-proxy` as an internal prototype for authenticated API
  server metrics collection

Current cluster reality outside this repo-managed slice:

- `metrics-server` also runs in `kube-system`, but it is currently a `k3s`
  managed component rather than a repo-managed workload here

The intended split is:

- this repo deploys the in-cluster telemetry components
- `nix-pi` extends Prometheus scrape configuration on `rpi-box-02`
- `nix-services` adds Grafana dashboards for the new telemetry

## Current Exposure Model

`kube-state-metrics` now stays internal as a `ClusterIP` service and is exposed
through Traefik ingress.

Current intended scrape path:

- `https://kube-state-metrics.<homelab-domain>/metrics`

This keeps cluster telemetry on the ingress path already used by other
cluster-side services instead of relying on a raw NodePort.

## Current Control-Plane Constraint

The next observability gap is deeper `k3s` control-plane telemetry.

The live cluster does expose relevant endpoints, but not in a directly
scrapeable way for the external Prometheus host:

- scheduler metrics are on `127.0.0.1:10259`
- controller-manager metrics are on `127.0.0.1:10257`
- kubelet metrics are on `:10250`
- API server metrics are on `:6443`

Current observed access behavior from `cluster-pi-01`:

- scheduler and controller-manager `/metrics` return `403`
- kubelet `/metrics` returns `401`
- API server `/metrics` returns `401`

That means the next step is not "open another host port and scrape it".

The next step is to choose a safe authenticated collection model before adding
control-plane metrics to the homelab monitoring stack.

The current repo-managed prototype for that direction is:

- `apiserver-metrics-proxy`
  - uses a service account plus RBAC for `/metrics`
  - fetches API server metrics from `https://kubernetes.default.svc/metrics`
  - re-exposes them as an internal `ClusterIP` service
  - intentionally does not add ingress or external scrape wiring yet

Build the manifests with:

```bash
nix run .#render-platform
```
