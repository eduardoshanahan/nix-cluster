# MetalLB

MetalLB provides bare-metal `LoadBalancer` IP allocation for services running
in the cluster.

Current deployment shape:

- namespace: `metallb-system`
- packaging: Helm chart via Kustomize
- announcement mode: Layer 2
- first address pool: `192.0.2.36-192.0.2.40`

## Pool Choice

The initial pool is intentionally small and sits next to the cluster node
reservations:

- cluster nodes use `192.0.2.31-192.0.2.35`
- MetalLB uses `192.0.2.36-192.0.2.40`

This range should remain reserved for cluster `LoadBalancer` services so that
future ingress or app endpoints do not collide with DHCP-managed hosts.

Build the manifests with:

```bash
nix run .#render-platform
```
