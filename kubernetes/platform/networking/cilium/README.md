# Cilium

Cilium is the CNI for the cluster. It runs in native routing mode with full
kube-proxy replacement.

## Deployment Shape

- **Packaging**: Helm chart via Kustomize
- **Mode**: native routing (no encapsulation)
- **kube-proxy replacement**: full
- **NetworkPolicy**: enforced

## Why Cilium

k3s ships with Flannel CNI and kube-proxy by default. Both are disabled here
in favour of Cilium, which provides:

- eBPF-based networking (lower overhead on Raspberry Pi)
- Native NetworkPolicy enforcement
- kube-proxy replacement (reduced hop count for service traffic)

## Build the Manifests

```bash
nix run .#render-platform
```

Cilium is included in the platform stack along with MetalLB and Traefik.

## Verify

```bash
# All Cilium pods running
kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium

# CNI connectivity
kubectl exec -n kube-system ds/cilium -- cilium-dbg status --brief
```
