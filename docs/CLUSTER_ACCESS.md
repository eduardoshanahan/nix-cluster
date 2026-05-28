# Cluster Access

## Node Inventory

| Node | Role | IP | Notes |
|------|------|----|-------|
| `cluster-pi-01` | control-plane (bootstrap) | `192.0.2.31` | first server, holds `--cluster-init` |
| `cluster-pi-02` | control-plane | `192.0.2.32` | |
| `cluster-pi-03` | control-plane | `192.0.2.33` | |
| `cluster-pi-04` | worker | `192.0.2.34` | |
| `cluster-pi-05` | worker | `192.0.2.35` | |

Cluster API endpoint: `cluster-api.<homelab-domain>:6443` — currently a DNS record pointing at `192.0.2.31`. Not a true HA load-balanced frontend; a single control-plane node is the actual target.

Traefik ingress LoadBalancer IP: `192.0.2.36` (MetalLB pool `192.0.2.36–192.0.2.40`).

## kubectl Setup

All cluster tooling (`kubectl`, `helm`, `k9s`, etc.) is in the devShell — use `nix develop`.

### 1. Copy kubeconfig from a control-plane node

```bash
ssh eduardo@cluster-pi-01.<homelab-domain> 'sudo cat /etc/rancher/k3s/k3s.yaml' \
  | sed 's|https://127.0.0.1:6443|https://cluster-api.<homelab-domain>:6443|' \
  > ~/.kube/config
chmod 600 ~/.kube/config
```

The raw kubeconfig has `server: https://127.0.0.1:6443` — the `sed` fixes it to the cluster API hostname.

### 2. Verify

```bash
nix develop --command kubectl get nodes
```

## Common Operations

```bash
# Cluster health
kubectl get nodes -o wide
kubectl get pods -A
kubectl top nodes

# Deploy platform manifests
nix run .#render-observability | kubectl apply -f -
nix run .#render-headlamp      | kubectl apply -f -

# Logs across a workload
nix develop --command stern -n observability .
```

## Exposed Services

| Service | URL |
|---------|-----|
| Headlamp | `https://headlamp.<homelab-domain>` |
| kube-state-metrics proxy | `https://kube-state-metrics.<homelab-domain>` |
| Spark History Server | `https://spark-history.<homelab-domain>` |

## Troubleshooting

**Connection refused / certificate errors** — re-copy the kubeconfig; the k3s CA may have been regenerated. Re-run the copy step above and replace `~/.kube/config`.

**kubectl not found** — run `nix develop` first; kubectl is only in the devShell.

**kubeconfig stale after node recovery** — if the cluster CA was regenerated (e.g., after a full etcd wipe), all existing kubeconfigs are invalid. Re-copy from a healthy control-plane node.

## References

- k3s NixOS module: `nixos/modules/k3s-common.nix`
- Private cluster values (bootstrap token, SSH keys, real hostnames): `../nix-cluster-private/modules/shared.nix`
