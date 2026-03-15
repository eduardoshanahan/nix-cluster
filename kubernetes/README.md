# Kubernetes Workloads

This directory is reserved for services that run on the cluster.

It exists to keep a clear separation between:

- host provisioning in `nixos/`
- cluster services and workloads in `kubernetes/`

Nothing here is in scope for the current restart. The current focus is still:

- stable Raspberry Pi bootstrap
- correct `k3s` role behavior
- validation before flashing
- post-boot deploy workflows

When workloads are introduced later, they should be added here rather than
mixed into the host provisioning modules.
