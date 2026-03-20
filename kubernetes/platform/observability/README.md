# Observability Workloads

This directory holds cluster-side observability components.

Phase 2 starts with:

- `kube-state-metrics` for Kubernetes object state telemetry

The intended split is:

- this repo deploys the in-cluster telemetry components
- `nix-pi` extends Prometheus scrape configuration on `rpi-box-02`
- `nix-services` adds Grafana dashboards for the new telemetry

## Current Exposure Model

For the first implementation pass, `kube-state-metrics` is exposed via a fixed
NodePort on TCP `30080`.

That is an intentionally simple bridge so the existing external Prometheus host
can start scraping Kubernetes-aware metrics before a more polished ingress or
authenticated proxy path is introduced.

Build the manifests with:

```bash
nix run .#render-observability
```
