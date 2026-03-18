# Headlamp

Headlamp provides a visual Kubernetes UI for learning and day-to-day cluster
inspection.

Current deployment shape:

- namespace: `headlamp`
- service type: `NodePort`
- exposed port: `30081`
- service account role: `cluster-admin`

This is intentionally convenient for a private homelab, but it should remain an
internal-only tool.

After deployment, access it at:

```text
http://cluster-pi-01.<homelab-domain>:30081/
```

Build the manifests with:

```bash
nix run .#render-headlamp
```
