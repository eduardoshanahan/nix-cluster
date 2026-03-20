# Headlamp Next Session Notes

## Current State

- Headlamp is installed in this repo under [kubernetes/operations/headlamp](/home/eduardo/Programming/gitea.<homelab-domain>/nix-cluster/kubernetes/operations/headlamp).
- Deployment pattern is `Kustomize` with a Helm chart.
- Headlamp now uses an internal `ClusterIP` service and a standard Kubernetes `Ingress`.
- The user created the DNS name `headlamp.<homelab-domain>`.

## Important Fix Already Applied

- The first Headlamp pod crashed because chart `0.40.1` injected the unsupported argument `-session-ttl=86400`.
- This was fixed with the Kustomize patch at [deployment-args-patch.yaml](/home/eduardo/Programming/gitea.<homelab-domain>/nix-cluster/kubernetes/operations/headlamp/deployment-args-patch.yaml).
- Good `nix-cluster` commit for this state: `6e5dcda` with message `Fix Headlamp startup arguments`.

## Verified Working

- cluster ingress now expects Traefik to own ports `80` and `443` on cluster nodes.
- The `headlamp` namespace exists.
- The Headlamp pod and `headlamp` service are still the backend.
- Traefik is now the intended front door for `headlamp.<homelab-domain>`.

## Current Next Check

- verify Traefik is listening on cluster node ports `80` and `443`
- verify `http://headlamp.<homelab-domain>/` resolves and reaches the ingress
- only add HTTPS after the cluster Traefik instance has a Kubernetes TLS secret
  backed by the chosen homelab certificate material

## Commands To Run On The Failing Host

```bash
getent ahosts headlamp.<homelab-domain>
curl -I --max-time 10 http://headlamp.<homelab-domain>/
curl -I --max-time 10 http://192.0.2.31/
nc -vz 192.0.2.31 80
```

## How To Read The Results

- If the hostname fails but the node IP works, it is a DNS issue.
- If both hostname and node IP fail, it is a network or firewall path issue from that host.
- If `curl` works but the browser fails, it is likely a browser cache, HTTPS, or HSTS issue.

## Workflow Reminder

- For git, nix, and deploy commands, use the repo's own `nix develop`.
- The current `nix-cluster` branch already contains the Headlamp changes and the startup-argument fix.

## Possible Follow-Up Improvement

- Reuse the same wildcard or internal CA certificate pattern as the rest of the homelab by creating a Kubernetes TLS secret for Traefik and then enabling `Ingress.spec.tls`.
