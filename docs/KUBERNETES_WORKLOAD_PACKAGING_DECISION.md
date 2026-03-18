# Kubernetes Workload Packaging Decision

## Status

Accepted on 2026-03-18.

## Context

This cluster exists for two purposes at once:

- learn Kubernetes clearly enough to operate it with confidence
- migrate selected homelab services from standalone boxes onto the cluster

That means the repository structure should:

- keep Kubernetes resources understandable and reviewable
- avoid turning every third-party deployment into hand-maintained YAML
- establish a reusable pattern before many workloads arrive

Phase 2 observability is the first cluster-side service that needs this
decision.

## Decision

Use:

- `Kustomize` as the repository-level composition model
- `Helm` selectively for upstream third-party applications
- plain YAML for small repo-owned resources and patches

Do not introduce a full GitOps controller yet.

## Why

### Why `Kustomize` first

- it keeps Kubernetes resources visible and teachable
- it gives the repo a clean hierarchy for namespaces, bases, overlays, and
  patches
- it avoids making every future service a special case

### Why mix in `Helm`

- infrastructure apps such as `kube-state-metrics` already have maintained
  upstream charts
- using those charts reduces repetitive YAML and makes upgrades clearer
- Helm is used as packaging, while Kustomize still owns repo structure

### Why not GitOps yet

- the cluster is still early in its lifecycle
- learning manifests, services, ingress, and rollout behavior directly is more
  valuable right now than adding Flux or Argo CD immediately
- a GitOps controller can be introduced later once several workloads are
  running and the operational pain is real

## Consequences

### Positive

- one consistent home for cluster workloads under `kubernetes/`
- good balance between learning value and maintainability
- easy path to add future observability, ingress, and migrated applications

### Tradeoffs

- operators must use the repo-provided Kubernetes app toolchain for Helm-backed
  workloads
- this is still a manual apply model for now
- chart versions need to be pinned and reviewed during upgrades

## Initial Structure

Phase 2 observability should establish:

- `kubernetes/observability/kustomization.yaml`
- `kubernetes/observability/namespace.yaml`
- `kubernetes/observability/kube-state-metrics/`

## Follow-On Direction

After the first few workloads are stable, re-evaluate whether to add:

- environment overlays beyond the current homelab
- a more formal deploy helper for Kubernetes apps
- GitOps with Flux or Argo CD
