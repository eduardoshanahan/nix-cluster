# Application Workloads

This directory is reserved for user-facing or service-specific workloads that
run on top of the cluster platform.

Examples include:

- migrated homelab applications
- app-specific databases that intentionally live inside the cluster
- app-level ingress, jobs, and supporting manifests tied to one service

## Boundary

Keep shared cluster platform services out of this directory. Those belong in
`kubernetes/platform/`.

Keep operator tooling such as cluster UIs and day-to-day admin helpers in
`kubernetes/operations/`.
