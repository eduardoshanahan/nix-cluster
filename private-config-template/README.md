# Private Config Template

This directory is the **fallback private flake** used when no real
`nix-cluster-private` sibling exists. It provides safe placeholder defaults so
the public repo evaluates without errors.

**Do not put real values here.** This template is tracked in the public repo.

---

## Purpose

The cluster flake is split into two sibling repos:

| Repo | Contains |
|------|----------|
| `nix-cluster` (this repo) | Public NixOS modules, Kubernetes manifests, render helpers |
| `nix-cluster-private` | Real SSH keys, bootstrap token, domain, builder keys, secrets |

`nix-cluster` references the private repo via the `private` flake input.
By default that input resolves to this template so the repo evaluates on
a fresh checkout.

---

## Creating a Real Private Flake

Copy this template to a sibling directory `../nix-cluster-private`, then fill
in the real values.

```bash
cp -r private-config-template ../nix-cluster-private
cd ../nix-cluster-private
git init
```

Edit `modules/shared.nix` and replace every placeholder with real values:

| Option | What to put |
|--------|-------------|
| `homelab.adminAuthorizedKeys` | Your SSH public key(s) |
| `homelab.domain` | Your internal homelab domain, e.g. `cluster.hhlab.home.arpa` |
| `homelab.cluster.apiServerEndpoint` | Your cluster API DNS name |
| `homelab.cluster.clusterToken` | A random bootstrap token (generate with `openssl rand -hex 32`) |
| `homelab.nix.trustedBuilderPublicKeys` | Public key(s) of your ARM builder(s) |
| `homelab.kubernetes.ingressTlsSecretName` | Name of the TLS secret on the cluster for Traefik ingress |
| `homelab.kubernetes.metallb.addressPool` | A reserved LAN range, e.g. `192.168.1.200-192.168.1.210` |

App-specific values (Wiki.js, Spark) can be added as needed — see
`nixos/modules/options.nix` in the public repo for the full option set.

---

## Overriding the Private Flake Path

By default the render helpers and deploy scripts look for
`../nix-cluster-private`. If your checkout is elsewhere:

```bash
export NIX_CLUSTER_PRIVATE_FLAKE=/absolute/path/to/nix-cluster-private
```

---

## Validation

After filling in real values, verify evaluation resolves correctly:

```bash
nix run "path:$PWD#validate-private-config" -- cluster-pi-01
```
