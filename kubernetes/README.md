# Kubernetes Workloads

This directory contains services that run on the cluster.

It exists to keep a clear separation between:

- host provisioning in `nixos/`
- in-cluster services and workloads in `kubernetes/`

## Packaging Decision

Cluster workloads in this repository use:

- `Kustomize` as the top-level composition layer
- `Helm` selectively for upstream third-party applications
- plain YAML for small repo-owned glue resources such as namespaces, ingress,
  and future network policies

This keeps the repo easy to learn from while avoiding hand-maintaining large
vendor manifests.

## Layout

Recommended structure:

- `kubernetes/platform/`: shared in-cluster platform components
- `kubernetes/operations/`: cluster operator tooling
- `kubernetes/apps/`: migrated or cluster-native applications

Within those areas, keep the existing Kustomize pattern:

- `kubernetes/<area>/<domain>/kustomization.yaml`: grouping and shared resources
- `kubernetes/<area>/<domain>/<app>/kustomization.yaml`: app-level composition
- `kubernetes/<area>/<domain>/<app>/values.yaml`: Helm values for third-party charts
- `kubernetes/<area>/<domain>/<app>/*.yaml`: repo-owned manifests and patches

The first real platform workload area is `kubernetes/platform/observability/`.

## Build And Apply

When a workload uses Helm-backed Kustomize, build the shared platform stack
with:

```bash
nix run .#render-platform
```

Render the operator tooling separately with:

```bash
nix run .#render-headlamp
```

These render helpers resolve environment-specific ingress and MetalLB values
from `../nix-cluster-private` by default. If your companion checkout lives
elsewhere, set `NIX_CLUSTER_PRIVATE_FLAKE=/absolute/path/to/nix-cluster-private`
before running them.

Apply the platform stack with:

```bash
nix run .#render-platform | kubectl apply -f -
```

The repo dev shell includes the toolchain needed for this workflow:

- `kubectl`
- `kustomize`
- `helm`

Build all current platform workloads with:

```bash
nix run .#render-platform
```

## Scope Boundary

Keep host concerns such as firewalling, OS packages, and `k3s` node behavior in
`nixos/`.

Keep shared cluster capabilities such as ingress, telemetry components, and
certificate automation in `kubernetes/platform/`.

Keep operator-facing tools in `kubernetes/operations/`.

Keep migrated applications and service-specific manifests in `kubernetes/apps/`.
