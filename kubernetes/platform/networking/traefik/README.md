# Traefik

Traefik is the cluster ingress controller for HTTP and HTTPS routing.

Current deployment shape:

- namespace: `traefik`
- packaging: Helm chart via Kustomize
- scheduling model: `Deployment` with two replicas
- exposure model: `LoadBalancer` service via MetalLB
- stable ingress IP: `192.0.2.36`
- ingress model: standard Kubernetes `Ingress` resources

This keeps the cluster aligned with the rest of the homelab, where Traefik is
the normal ingress entrypoint.

Pi-hole and any other LAN DNS should point ingress hostnames at the Traefik
service IP rather than a specific node IP.

## TLS Reuse Model

This repo does not commit certificate material.

If you want `headlamp.<homelab-domain>` to use the same wildcard or internal CA
certificate pattern as the rest of the homelab, provide equivalent certificate
material to the cluster out of band as a Kubernetes TLS secret and reference it
from the `Ingress`.

That means the same certificate strategy is possible here, but the cert/key
must be provisioned operationally rather than stored in Git.

Build the manifests with:

```bash
nix run .#render-platform
```
