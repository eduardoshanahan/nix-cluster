# nix-cluster

Declarative NixOS-based Kubernetes cluster for the homelab Raspberry Pi fleet.

## Current Status

**Cluster is running (as of 2026-05-27).**

- 5 Raspberry Pi 4 nodes (8 GB RAM each), NixOS, k3s from nixos-unstable
- 3 control-plane/etcd nodes (cluster-pi-01/02/03), 2 workers (cluster-pi-04/05)
- Cilium 1.19.4 CNI — native routing, full kube-proxy replacement, NetworkPolicy enforced
- MetalLB — `192.0.2.36` assigned to Traefik ingress
- All platform pods healthy: Cilium, CoreDNS, metrics-server, MetalLB, Traefik, kube-state-metrics, apiserver-metrics-proxy, kubelet-metrics-proxy
- Observability complete — node-exporter, kube-state-metrics, cAdvisor (kubelet-metrics-proxy), apiserver metrics all scraped by rpi-box-02; dashboards and alert rules active

## Prerequisites

- [Nix](https://nixos.org/download/) with flakes enabled (`experimental-features = nix-command flakes` in `~/.config/nix/nix.conf`)
- [direnv](https://direnv.net/) — run `direnv allow` once after cloning to get the dev shell on `cd`
- A sibling `nix-cluster-private` directory — see `private-config-template/README.md` to create one

The dev shell (`nix develop` or via direnv) provides `kubectl`, `kustomize`, `helm`, `k9s`, and `stern`.

## Private Config Workflow

Private cluster values are expected from a sibling flake:

- `../nix-cluster-private`

The tracked placeholder contract lives in:

- `private-config-template/`

The repo has an explicit preflight check for the private input:

- `nix run "path:$PWD#validate-private-config" -- cluster-pi-01`

The repo also has a session grounding helper that validates core docs and KB
index availability:

- `nix run .#session-preflight`

Use that helper before deploys, validations, and Kubernetes manifest renders.

By default the helper scripts look for `../nix-cluster-private`.
If your private flake lives elsewhere, set:

- `NIX_CLUSTER_PRIVATE_FLAKE=/absolute/path/to/nix-cluster-private`

The Kubernetes render helpers also consume the sibling private flake for
environment-specific values such as ingress hostnames, ingress TLS secret
names, and MetalLB address pools.

Validate and deploy node configs with path-based flake refs so the local
flake path and private override are included in evaluation:

- `path:$PWD#nixosConfigurations.<node>`

## Deploying

The deploy helper supports cross-host builds and self-builds:

- Cross-host: `NIX_CLUSTER_BUILD_HOST=rpi-box-01 ./deploy.sh cluster-pi-01`
- Self-build fallback: `./deploy.sh --self-build cluster-pi-01`

See `docs/NODE_DEPLOYMENT_RUNBOOK.md` for the full operator runbook.

## Start Here

- `README.md` (this file)
- `docs/CLUSTER_ACCESS.md` — node inventory, kubectl setup, exposed services
- `docs/NODE_DEPLOYMENT_RUNBOOK.md` — deploy and recovery procedures
- `docs/OBSERVABILITY.md` — Prometheus scrape jobs, dashboards, alert rules

## Repository Layout

- `flake.nix`: Nix flake entrypoint
- `private-config-template/`: tracked placeholder private flake contract
- `nixos/modules/`: shared NixOS modules
- `nixos/profiles/`: reusable profiles
- `nixos/hosts/`: public node definitions
- `kubernetes/`: in-cluster definitions — platform services, operator tooling, and applications; Kustomize top-level layout with Helm selectively for upstream charts
- `docs/`: operator documentation

## Working Rule

We may read from `../nix-pi`, `../nix-services`, and `../synology-services`
for context.

We must not edit those repositories without explicit authorization.
