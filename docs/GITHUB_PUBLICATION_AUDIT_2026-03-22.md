# GitHub Publication Audit: 2026-03-22

## Purpose

This note records the publication-hardening pass for `nix-cluster` and the
remaining work before pushing the repo to a public GitHub remote.

## Completed In This Session

- moved active Kubernetes environment-specific values behind the existing
  `../nix-cluster-private` flake contract
- added private-config-backed render support for:
  - ingress hostnames
  - ingress TLS secret name
  - MetalLB address pool
  - Traefik pinned `LoadBalancer` IP
  - namespace/annotation domain label prefixes
- replaced tracked example SSH keys with placeholders
- replaced tracked example domain and endpoint values with placeholders
- removed tracked `.direnv/` artifacts from Git and ignored them going forward
- removed the legacy local `nixos/hosts/private/overrides.nix` from the public
  repo tree because its values already live in `nix-cluster-private`
- sanitized the current `docs/` tree to replace live domains, LAN IPs,
  workstation-specific paths, and other operator-specific examples with
  placeholders or RFC example ranges
- removed two unrelated `nix-pi` migration handoffs from this repo because
  they carried extra private operational detail and did not belong in the
  public cluster repo

## Current Private Source Of Truth

The real values now expected from `nix-cluster-private` include:

- `homelab.adminAuthorizedKeys`
- `homelab.domain`
- `homelab.cluster.apiServerEndpoint`
- `homelab.cluster.clusterToken`
- `homelab.nix.trustedBuilderPublicKeys`
- `homelab.kubernetes.ingressTlsSecretName`
- `homelab.kubernetes.metallb.addressPool`

The public repo placeholder contract for those values lives in:

- `private-config-template/modules/shared.nix`

## Validated Design Intent

The intended operator workflow remains:

1. keep the real values in `../nix-cluster-private`
2. run `nix run "path:$PWD#validate-private-config" -- cluster-pi-01`
3. run host validation or deploy helpers as usual
4. run `nix run .#render-platform` or `nix run .#render-headlamp`
5. let those render helpers pull the private ingress and MetalLB values
   automatically without ad hoc manual edits

## Remaining Publication Risks

The active config path is much safer now, but the repo is not yet fully ready
for public publication.

### 1. Git history still contains previously tracked private values

Even if the current tree is sanitized, old commits may still contain:

- real SSH public keys
- the real cluster bootstrap token
- real builder public keys
- real domain and LAN details

Before making the repo public, inspect history and rewrite it if needed.

Confirmed examples found during this session:

- builder public key still appears in commits:
  - `f8e7e5a`
  - `3ede52c`
- operator SSH public key still appears in commits:
  - `ae9bd6b`
  - `95a1639`

## Recommended Next Step

Rewrite history before the first public push, then force-push the sanitized
branch to the new public remote.
