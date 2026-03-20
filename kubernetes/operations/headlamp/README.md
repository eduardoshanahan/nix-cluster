# Headlamp

Headlamp provides a visual Kubernetes UI for learning and day-to-day cluster
inspection.

Current deployment shape:

- namespace: `headlamp`
- service type: `ClusterIP`
- ingress hostname: `headlamp.<homelab-domain>`
- service account role: `cluster-admin`

This remains an internal-only tool. It is now intended to sit behind the
cluster Traefik ingress instead of being exposed directly via a `NodePort`.

After deployment, access it at:

```text
http://headlamp.<homelab-domain>/
```

Build the manifests with:

```bash
nix run .#render-headlamp
```
