# kubectl Access for nix-cluster

This document describes how to configure kubectl to access the nix-cluster Kubernetes cluster.

## Overview

The nix-cluster runs k3s on Raspberry Pi nodes. The kubeconfig file is generated on the control plane nodes at `/etc/rancher/k3s/k3s.yaml` with read permissions (0644) as configured in `nixos/modules/k3s-common.nix`.

## Initial Setup

### 1. Copy kubeconfig from a Control Plane Node

The cluster has multiple control plane nodes (cluster-pi-01, cluster-pi-02, cluster-pi-03). Copy the kubeconfig from any control plane node:

```bash
# Copy kubeconfig from cluster-pi-01
ssh -o StrictHostKeyChecking=accept-new eduardo@cluster-pi-01.hhlab.home.arpa 'cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/config
chmod 600 ~/.kube/config
```

### 2. Fix the Server Endpoint

The kubeconfig copied from the node will have `server: https://127.0.0.1:6443`. Update it to use the cluster API endpoint:

```bash
sed -i 's|https://127.0.0.1:6443|https://cluster-api.hhlab.home.arpa:6443|g' ~/.kube/config
```

### 3. Verify Access

```bash
# Using kubectl from nix dev shell
nix develop --command kubectl get nodes

# Or add kubectl to your PATH from the dev shell
nix develop
kubectl get nodes
```

## Cluster Nodes

The cluster consists of 5 Raspberry Pi 4 nodes:

| Hostname | FQDN | IP Address | Role |
|----------|------|------------|------|
| cluster-pi-01 | cluster-pi-01.hhlab.home.arpa | 192.168.1.31 | Control Plane (bootstrap) |
| cluster-pi-02 | cluster-pi-02.hhlab.home.arpa | 192.168.1.32 | Control Plane |
| cluster-pi-03 | cluster-pi-03.hhlab.home.arpa | 192.168.1.33 | Control Plane |
| cluster-pi-04 | cluster-pi-04.hhlab.home.arpa | 192.168.1.34 | Worker |
| cluster-pi-05 | cluster-pi-05.hhlab.home.arpa | 192.168.1.35 | Worker |

The cluster API endpoint is load-balanced across control plane nodes via DNS: `cluster-api.hhlab.home.arpa:6443`

## Common Operations

### Deploying Kubernetes Resources

```bash
# Render platform manifests
nix run .#render-platform | kubectl apply -f -

# Render Spark manifests
nix run .#render-spark | kubectl apply -f -

# Render Headlamp dashboard
nix run .#render-headlamp | kubectl apply -f -
```

### Checking Cluster Health

```bash
kubectl get nodes
kubectl get pods -A
kubectl top nodes
kubectl describe resourcequota -A
```

### Accessing Services

Services are exposed via Traefik ingress with TLS:
- Headlamp dashboard: `https://headlamp.hhlab.home.arpa`
- Spark History Server: `https://spark-history.hhlab.home.arpa`
- Prometheus: `https://prometheus.hhlab.home.arpa`
- Grafana: `https://grafana.hhlab.home.arpa`

## Troubleshooting

### kubeconfig Not Found

If `~/.kube/config` doesn't exist, follow the Initial Setup steps above.

### Connection Refused

If you get "connection refused" errors:
1. Verify the cluster API endpoint is correct: `https://cluster-api.hhlab.home.arpa:6443`
2. Check DNS resolution: `host cluster-api.hhlab.home.arpa`
3. Verify SSH access to control plane nodes
4. Ensure k3s is running on the control plane nodes

### Certificate Errors

The kubeconfig includes the cluster CA certificate. If you see certificate errors:
1. Re-copy the kubeconfig from a control plane node
2. Verify the `cluster-api.hhlab.home.arpa` hostname matches the TLS SAN in the k3s configuration

### kubectl Command Not Found

kubectl is available in the nix development shell:
```bash
nix develop
```

Or use it directly:
```bash
nix develop --command kubectl <command>
```

## Authentication

The kubeconfig uses a client certificate for authentication. This is automatically provisioned by k3s and copied with the kubeconfig file.

Access control is managed via Kubernetes RBAC. The default admin certificate from k3s has cluster-admin privileges.

## References

- k3s configuration: `nixos/modules/k3s-common.nix`
- Cluster networking: `nixos/modules/k3s-common.nix` (firewall rules, API endpoint)
- Private cluster values: `../nix-cluster-private/modules/shared.nix`
