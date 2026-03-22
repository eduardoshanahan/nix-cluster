# nix-cluster

Declarative NixOS-based Kubernetes cluster work for the homelab Raspberry Pi
fleet.

## Current Status

We are intentionally restarting the implementation workflow after learning that
the first per-node SD-card approach was too brittle.

The cluster shape is still the same:

- five Raspberry Pi 4 nodes with 8 GB RAM each
- NixOS on every node
- `k3s`
- 3 control-plane nodes and 2 workers
- no workload migration yet

What changes now is the provisioning workflow.

## New Direction

The cluster should be built around:

- one known-good Raspberry Pi 4 base image
- node-specific configuration applied after first boot
- minimal per-node differences
- clear separation between Pi host provisioning and services running on the
  cluster
- validation of generated `k3s` units before flashing
- post-boot deploys for most changes instead of repeated reflashing

The goal is to make the cluster easier to understand, safer to iterate on, and
more aligned with good NixOS and homelab practices.

## Current Rollout Direction

The active rollout plan is:

- keep the shared bootstrap-image workflow
- use post-boot deploys for node conversion
- use `rpi-box-01` as the shared ARM builder
- make cluster nodes trust the builder signing key through
  `homelab.nix.trustedBuilderPublicKeys`
- preserve a first-boot recovery path for stale `k3s` state

The deploy helper in this repo now supports both:

- cross-host deploys with `--build-host`
- explicit target self-builds with `--self-build`

See `docs/NEXT_SESSION_ROLLOUT_NOTES_2026-03-17.md` for the operator runbook.

## Private Config Workflow

Private cluster values are now expected from a sibling flake:

- `../nix-cluster-private`

The tracked placeholder contract lives in:

- `private-config-template/`

The repo has an explicit preflight check for the private input:

- `nix run "path:$PWD#validate-private-config" -- cluster-pi-01`

Use that helper before deploys, validations, and Kubernetes manifest renders.

By default the helper scripts look for `../nix-cluster-private`.
If your private flake lives elsewhere, set:

- `NIX_CLUSTER_PRIVATE_FLAKE=/absolute/path/to/nix-cluster-private`

The Kubernetes render helpers also consume the sibling private flake for
environment-specific values such as ingress hostnames, ingress TLS secret
names, and MetalLB address pools.

Important: validate and deploy node configs with path-based flake refs so the
local flake path and private override are included in evaluation:

- `path:$PWD#nixosConfigurations.<node>`

Do not rely on plain `.#nixosConfigurations.<node>` when checking private
config presence.

## Start Here

- `HOMELAB_AND_CLUSTER_CONTEXT.md`
- `docs/PRIVATE_COMPANION_REPO_CONVENTION.md`
- `docs/RESTART_PLAN.md`
- `docs/LESSONS_LEARNED.md`
- `docs/NODE_INVENTORY_TEMPLATE.md`

## Repository Layout

- `flake.nix`: Nix flake entrypoint
- `private-config-template/`: tracked placeholder private flake contract
- `nixos/modules/`: shared NixOS modules
- `nixos/profiles/`: reusable profiles
- `nixos/hosts/`: public node definitions
- `nixos/hosts/private/`: legacy local override examples kept as migration
  reference
- `kubernetes/`: in-cluster definitions, split into shared platform services,
  operator tooling, and future applications, using Kustomize as the top-level
  layout and Helm selectively for upstream apps
- `docs/`: operator documentation and planning

## Working Rule

We may read from `../nix-pi`, `../nix-services`, and `../synology-services`
for context.

We must not edit those repositories without explicit authorization.
