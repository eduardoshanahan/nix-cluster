# Observability Workloads

Cluster-side telemetry components. All scrape endpoints are exposed through
Traefik ingress via TLS; the external Prometheus host (`rpi-box-02`) scrapes
them over HTTPS.

See `docs/OBSERVABILITY.md` for the full scrape inventory, Grafana dashboards,
and alert rules.

## Components

| Component | Namespace | What it does |
|-----------|-----------|--------------|
| `kube-state-metrics` | `observability` | Kubernetes object state (nodes, pods, deployments) |
| `apiserver-metrics-proxy` | `observability` | Proxies `https://kubernetes.default.svc/metrics` with in-cluster auth |
| `kubelet-metrics-proxy` | `observability` | Fetches `/metrics/cadvisor` from all 5 nodes via K8s API proxy |
| `control-plane-metrics-proxy` | `observability` | Aggregates scheduler (`:10259`) and controller-manager (`:10257`) from control-plane nodes |

`metrics-server` also runs in `kube-system`, but it is a k3s-managed component
rather than a repo-managed workload.

## Exposure Model

All components are `ClusterIP` services exposed through Traefik ingress:

- `https://kube-state-metrics.<homelab-domain>/metrics`
- `https://kube-state-metrics.<homelab-domain>/apiserver-metrics`
- `https://kube-state-metrics.<homelab-domain>/cadvisor-metrics`
- `https://kube-state-metrics.<homelab-domain>/scheduler-metrics`
- `https://kube-state-metrics.<homelab-domain>/controller-manager-metrics`

## Build the Manifests

```bash
nix run .#render-platform
```

Or render the observability stack in isolation:

```bash
nix run .#render-observability
```
