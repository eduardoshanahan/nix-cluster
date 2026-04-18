# Application Workloads

This directory is reserved for user-facing or service-specific workloads that
run on top of the cluster platform.

Examples include:

- migrated homelab applications
- app-specific databases that intentionally live inside the cluster
- app-level ingress, jobs, and supporting manifests tied to one service

Current app workload areas include:

- `kafka/` for a 3-broker Kafka cluster (KRaft), Schema Registry, and Kafka UI — for CCDAK certification study
- `spark/` for the Spark operator, history server, and examples
- `wikijs/` for the first user-facing knowledge base workload on the cluster

## Boundary

Keep shared cluster platform services out of this directory. Those belong in
`kubernetes/platform/`.

Keep operator tooling such as cluster UIs and day-to-day admin helpers in
`kubernetes/operations/`.
