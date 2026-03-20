# Headlamp Next Session Notes

## Current State

- Headlamp is installed in this repo under [kubernetes/operations/headlamp](/home/eduardo/Programming/gitea.<homelab-domain>/nix-cluster/kubernetes/operations/headlamp).
- Deployment pattern is `Kustomize` with a Helm chart.
- Headlamp is exposed with a `NodePort` on `30081`.
- The user created the DNS name `headlamp.<homelab-domain>`.

## Important Fix Already Applied

- The first Headlamp pod crashed because chart `0.40.1` injected the unsupported argument `-session-ttl=86400`.
- This was fixed with the Kustomize patch at [deployment-args-patch.yaml](/home/eduardo/Programming/gitea.<homelab-domain>/nix-cluster/kubernetes/operations/headlamp/deployment-args-patch.yaml).
- Good `nix-cluster` commit for this state: `6e5dcda` with message `Fix Headlamp startup arguments`.

## Verified Working

- `cluster-pi-01` was deployed with firewall port `30081` open.
- The `headlamp` namespace exists.
- The Headlamp pod is `Running`.
- The Headlamp service has endpoints.
- `curl -I http://headlamp.<homelab-domain>:30081/` returned `HTTP/1.1 200 OK` from this machine.
- `curl -I http://headlamp.<homelab-domain>:30081/` also returned `HTTP/1.1 200 OK` from `cluster-pi-01`.
- `localhost:30081` on `cluster-pi-01` did not answer, but the node IP and FQDN did. That did not block the working path.

## Open Issue To Investigate

- From another host, `http://headlamp.<homelab-domain>:30081/` timed out.
- Since the service works from this machine and from `cluster-pi-01`, the likely causes are:
  - stale or wrong DNS on the failing host
  - network or firewall reachability from that host to `192.0.2.31:30081`
  - browser cache, HTTPS forcing, or HSTS on that host

## Commands To Run On The Failing Host

```bash
getent ahosts headlamp.<homelab-domain>
curl -I --max-time 10 http://headlamp.<homelab-domain>:30081/
curl -I --max-time 10 http://192.0.2.31:30081/
nc -vz 192.0.2.31 30081
```

## How To Read The Results

- If the hostname fails but the IP works, it is a DNS issue.
- If both hostname and IP fail, it is a network or firewall path issue from that host.
- If `curl` works but the browser fails, it is likely a browser cache, HTTPS, or HSTS issue.

## Workflow Reminder

- For git, nix, and deploy commands, use the repo's own `nix develop`.
- The current `nix-cluster` branch already contains the Headlamp changes and the startup-argument fix.

## Possible Follow-Up Improvement

- Move Headlamp off `NodePort` and behind ingress or a reverse proxy so it can use a clean hostname without `:30081`, and later add TLS.
