# Cluster Observability

Current deployed architecture across all four implementation phases (all complete as of 2026-04-23).

## Prometheus Jobs

| Job | Source | Ingress path | Interval |
|-----|--------|--------------|----------|
| `nodes` | node_exporter on each Pi, port 9100 | direct scrape from rpi-box-02 | default |
| `kube-state-metrics` | kube-state-metrics ClusterIP | `kube-state-metrics.<homelab-domain>/metrics` | default |
| `kube-apiserver-metrics` | apiserver-metrics-proxy ClusterIP | `kube-state-metrics.<homelab-domain>/apiserver-metrics` | default |
| `kubelet-cadvisor` | kubelet-metrics-proxy, all 5 nodes | `kube-state-metrics.<homelab-domain>/cadvisor-metrics` | default |
| `kube-scheduler` | control-plane-metrics-proxy → `:10259` | `kube-state-metrics.<homelab-domain>/scheduler-metrics` | 60s / 30s timeout |
| `kube-controller-manager` | control-plane-metrics-proxy → `:10257` | `kube-state-metrics.<homelab-domain>/controller-manager-metrics` | 60s / 30s timeout |

All ingress routes use TLS via the shared homelab wildcard cert on Traefik.

## Cluster-Side Components

All live under `kubernetes/platform/observability/`.

| Component | Namespace | What it does |
|-----------|-----------|--------------|
| `kube-state-metrics` | `observability` | Kubernetes object state (nodes, pods, deployments) |
| `apiserver-metrics-proxy` | `observability` | Proxies `https://kubernetes.default.svc/metrics` with in-cluster auth |
| `kubelet-metrics-proxy` | `observability` | Fetches `/metrics/cadvisor` from all 5 nodes via K8s API proxy |
| `control-plane-metrics-proxy` | `observability` | Aggregates scheduler (`:10259`) and controller-manager (`:10257`) from all 3 control-plane nodes |

### Node exporter

Enabled on all 5 nodes via `homelab.observability.nodeExporter`. Port 9100 is open in the firewall.

### Scheduler and controller-manager exposure

k3s flags in `nixos/modules/k3s-common.nix` bind both listeners to `0.0.0.0` and bypass RBAC for `/metrics`:

```
--kube-scheduler-arg=bind-address=0.0.0.0
--kube-scheduler-arg=authorization-always-allow-paths=/metrics,/healthz,/readyz
--kube-controller-manager-arg=bind-address=0.0.0.0
--kube-controller-manager-arg=authorization-always-allow-paths=/metrics,/healthz,/readyz
```

Ports 10257 and 10259 are open in the firewall on control-plane nodes only.

## Monitoring-Side Configuration (rpi-box-02 in nix-pi-private)

- `monitoringTargets.node` includes all 5 cluster nodes at `<hostname>.<homelab-domain>:9100`
- `kubeStateMetricsTargets` and `kubeApiServerMetricsTargets` point at `kube-state-metrics.<homelab-domain>:443`
- `extraStaticJobs` entries for `kubelet-cadvisor`, `kube-scheduler`, `kube-controller-manager`
- Uptime Kuma monitors: Kubernetes API (TCP), node exporters (HTTP), kube-state-metrics, apiserver-metrics-proxy, kubelet-cadvisor-proxy, kube-scheduler, kube-controller-manager (all keyword monitors)

## Grafana (nix-services)

- `kubernetes-overview` dashboard uses `job="kube-state-metrics"`
- Cluster Pi host dashboards use `job="nodes"` — same job as other homelab nodes
- Alert rules active for `KubernetesNodeNotReady`, `KubernetesPodRestarting`, and others

## Repository Ownership

| Concern | Repo |
|---------|------|
| In-cluster proxy and exporter manifests | `nix-cluster` (`kubernetes/platform/observability/`) |
| k3s flags for metrics exposure | `nix-cluster` (`nixos/modules/k3s-common.nix`) |
| Prometheus scrape inventory | `nix-pi-private` (rpi-box-02 module) |
| Uptime Kuma monitor inventory | `nix-pi-private` (rpi-box-02 module) |
| Grafana dashboards and alert rules | `nix-services` |

## Validation

```bash
# Prometheus targets up
kubectl exec -n observability deploy/kube-state-metrics -- wget -qO- http://localhost:8080/metrics | head -3

# All cluster node exporters reachable
for h in cluster-pi-01 cluster-pi-02 cluster-pi-03 cluster-pi-04 cluster-pi-05; do
  curl -fsS "http://${h}.<homelab-domain>:9100/metrics" >/dev/null && echo "OK $h"
done

# Proxy ingress endpoints
curl -fsS https://kube-state-metrics.<homelab-domain>/metrics | head -3
curl -fsS https://kube-state-metrics.<homelab-domain>/apiserver-metrics | head -3
curl -fsS https://kube-state-metrics.<homelab-domain>/cadvisor-metrics | head -3
curl -fsS https://kube-state-metrics.<homelab-domain>/scheduler-metrics | head -3
curl -fsS https://kube-state-metrics.<homelab-domain>/controller-manager-metrics | head -3
```

On rpi-box-02 after a nix-pi deploy:

```bash
sudo docker exec prometheus wget -qO- 'http://127.0.0.1:9090/api/v1/targets' \
  | python3 -m json.tool | grep '"health"'
```

All six jobs should show `"health": "up"`.
