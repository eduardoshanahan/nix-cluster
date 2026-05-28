# Networking Platform Components

This directory holds shared cluster networking components.

Current components:

- `cilium` — CNI, native routing, full kube-proxy replacement, NetworkPolicy
- `traefik` — ingress controller
- `metallb` — bare-metal `LoadBalancer` IP allocation

The current homelab LAN address pool is:

- configured through `homelab.kubernetes.metallb.addressPool` in
  `nix-cluster-private`

Build the manifests with:

```bash
nix run .#render-platform
```
