# MetalLB

MetalLB provides bare-metal `LoadBalancer` IP allocation for services running
in the cluster.

Current deployment shape:

- namespace: `metallb-system`
- packaging: Helm chart via Kustomize
- announcement mode: Layer 2
- first address pool: from `homelab.kubernetes.metallb.addressPool`

## Pool Choice

The initial pool should remain a small reserved range for cluster
`LoadBalancer` services so that future ingress or app endpoints do not collide
with DHCP-managed hosts.

Build the manifests with:

```bash
nix run .#render-platform
```
