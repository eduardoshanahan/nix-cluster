# Headlamp Next Session Notes

## Current State

- Headlamp is installed in this repo under [kubernetes/operations/headlamp](/home/eduardo/Programming/gitea.<homelab-domain>/nix-cluster/kubernetes/operations/headlamp).
- Deployment pattern is `Kustomize` with a Helm chart.
- Headlamp now uses an internal `ClusterIP` service and a standard Kubernetes `Ingress`.
- The user created the DNS name `headlamp.<homelab-domain>`.
- Traefik now sits behind MetalLB on `192.0.2.36`.
- Pi-hole should point ingress hostnames at `192.0.2.36`, not at a node IP.
- Headlamp now serves over HTTPS with the shared homelab wildcard certificate.

## Important Fix Already Applied

- The first Headlamp pod crashed because chart `0.40.1` injected the unsupported argument `-session-ttl=86400`.
- This was fixed with the Kustomize patch at [deployment-args-patch.yaml](/home/eduardo/Programming/gitea.<homelab-domain>/nix-cluster/kubernetes/operations/headlamp/deployment-args-patch.yaml).
- Good `nix-cluster` commit for this state: `6e5dcda` with message `Fix Headlamp startup arguments`.

## Verified Working

- cluster ingress now expects Traefik to own ports `80` and `443` on cluster nodes.
- The `headlamp` namespace exists.
- The Headlamp pod and `headlamp` service are still the backend.
- Traefik is now the intended front door for `headlamp.<homelab-domain>`.

## Operator Runbook

### Verify Access Path

```bash
getent ahosts headlamp.<homelab-domain>
curl -I --max-time 10 http://headlamp.<homelab-domain>/
curl -k -I --max-time 10 https://headlamp.<homelab-domain>/
curl -I --max-time 10 http://192.0.2.36/
curl -k -I --max-time 10 https://192.0.2.36/ -H 'Host: headlamp.<homelab-domain>'
```

### Refresh The Shared TLS Secret

The cluster currently reuses the wildcard certificate from `rpi-box-01`.

```bash
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes operator@192.0.2.10 \
  'sudo cat /run/secrets/traefik/tls.crt' >/tmp/homelab-wildcard.crt

ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes operator@192.0.2.10 \
  'sudo cat /run/secrets/traefik/tls.key' >/tmp/homelab-wildcard.key

ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes operator@192.0.2.31 \
  'cat >/tmp/homelab-wildcard.crt' </tmp/homelab-wildcard.crt

ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes operator@192.0.2.31 \
  'cat >/tmp/homelab-wildcard.key' </tmp/homelab-wildcard.key

ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes operator@192.0.2.31 \
  'sudo k3s kubectl -n headlamp create secret tls <private-ingress-tls-secret> \
    --cert=/tmp/homelab-wildcard.crt \
    --key=/tmp/homelab-wildcard.key \
    --dry-run=client -o yaml | sudo k3s kubectl apply -f -'
```

If you refresh the secret manually, clean up the temporary files afterwards.

### Mint A Fresh Headlamp Token

```bash
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.31 \
  'sudo k3s kubectl -n headlamp create token headlamp-admin'
```

This token is currently full `cluster-admin`.

## How To Read The Results

- If the hostname fails but `192.0.2.36` works, it is a DNS issue.
- If both hostname and `192.0.2.36` fail, it is a network or ingress issue.
- If `curl` works but the browser fails, it is likely a browser cache, HTTPS, or HSTS issue.

## Workflow Reminder

- For git, nix, and deploy commands, use the repo's own `nix develop`.
- The current `nix-cluster` branch already contains the Headlamp changes and the startup-argument fix.

## Possible Follow-Up Improvement

- Replace the ad hoc `cluster-admin` token flow with a safer auth model for Headlamp.
