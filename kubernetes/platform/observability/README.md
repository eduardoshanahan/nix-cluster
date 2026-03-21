# Observability Workloads

This directory holds cluster-side observability components.

Current components:

- `kube-state-metrics` for Kubernetes object state telemetry

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

Build the manifests with:

```bash
nix run .#render-platform
```
