# Networking Platform Components

This directory holds shared cluster networking components.

Current components:

- `traefik` as the ingress controller
- `metallb` for bare-metal `LoadBalancer` IP allocation

The current homelab LAN address pool is:

- `192.168.1.36-192.168.1.40`

Build the manifests with:

```bash
nix run .#render-platform
```
