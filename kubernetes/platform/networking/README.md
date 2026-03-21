# Networking Platform Components

This directory holds shared cluster networking components.

Current components:

- `traefik` as the ingress controller
- `metallb` for bare-metal `LoadBalancer` IP allocation

The current homelab LAN address pool is:

- `192.0.2.36-192.0.2.40`

Build the manifests with:

```bash
nix run .#render-platform
```
