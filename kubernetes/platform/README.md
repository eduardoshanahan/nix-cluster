# Platform Workloads

This directory holds shared cluster platform components.

These are not end-user applications. They are the reusable building blocks that
make the cluster usable and operable.

Examples include:

- ingress controllers such as Traefik
- cluster observability components such as `kube-state-metrics`
- future networking components such as MetalLB or ExternalDNS
- future certificate automation such as cert-manager

## Boundary

Keep shared cluster capabilities here.

Do not place Raspberry Pi host concerns here. Those belong in `nixos/`.

Do not place migrated user-facing applications here. Those belong in
`kubernetes/apps/`.

Build all platform manifests with:

```bash
nix run .#render-platform
```

Current networking components under `kubernetes/platform/networking/` include:

- `traefik` for ingress
- `metallb` for bare-metal `LoadBalancer` IPs
