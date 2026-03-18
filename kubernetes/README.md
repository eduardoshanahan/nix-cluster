# Kubernetes Workloads

This directory contains services that run on the cluster.

It exists to keep a clear separation between:

- host provisioning in `nixos/`
- cluster services and workloads in `kubernetes/`

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

- `kubernetes/<domain>/kustomization.yaml`: app grouping and shared resources
- `kubernetes/<domain>/<app>/kustomization.yaml`: app-level composition
- `kubernetes/<domain>/<app>/values.yaml`: Helm values for third-party charts
- `kubernetes/<domain>/<app>/*.yaml`: repo-owned manifests and patches

The first real workload area is `kubernetes/observability/`.

## Build And Apply

When a workload uses Helm-backed Kustomize, build it with:

```bash
nix run .#render-observability
```

Apply it with:

```bash
nix run .#render-observability | kubectl apply -f -
```

The repo dev shell includes the toolchain needed for this workflow:

- `kubectl`
- `kustomize`
- `helm`

## Scope Boundary

Keep host concerns such as firewalling, OS packages, and `k3s` node behavior in
`nixos/`.

Keep in-cluster applications such as telemetry exporters, ingress objects, and
future migrated services in `kubernetes/`.
