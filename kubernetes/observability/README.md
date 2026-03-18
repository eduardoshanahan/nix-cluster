# Observability Workloads

This directory holds cluster-side observability components.

Phase 2 starts with:

- `kube-state-metrics` for Kubernetes object state telemetry

The intended split is:

- this repo deploys the in-cluster telemetry components
- `nix-pi` extends Prometheus scrape configuration on `rpi-box-02`
- `nix-services` adds Grafana dashboards for the new telemetry

Build the manifests with:

```bash
nix run .#render-observability
```
