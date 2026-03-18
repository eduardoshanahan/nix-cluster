# Kubernetes Learning Toolkit

## Purpose

This note defines the recommended learning tools and workflow for this cluster.

The goal is not just to operate Kubernetes, but to understand what the cluster
is doing and why.

## Recommended Tools

The `nix-cluster` dev shell includes:

- `kubectl`
- `k9s`
- `Headlamp` is deployed in-cluster as a visual UI
- `helm`
- `kustomize`
- `stern`
- `kubectx`
- `kubens`

Recommended learning order:

1. `kubectl`
2. `k9s`
3. `helm`
4. `kustomize`
5. `stern`

## Rule Of Thumb

Use `kubectl` as the primary learning tool.

Use the others to speed up exploration, but always learn the corresponding
`kubectl` command for anything important.

For example:

- if you inspect a pod in `k9s`, also learn `kubectl describe pod`
- if you tail logs with `stern`, also learn `kubectl logs`
- if you inspect rendered manifests from Helm, also learn how `kustomize`
  composes them in this repo

## Enter The Tooling Environment

From this repository:

```bash
nix develop
```

## Practical Learning Workflow

### 1. Learn the current cluster shape

```bash
kubectl get nodes -o wide
kubectl get ns
kubectl get pods -A -o wide
```

What to notice:

- which nodes exist
- which namespaces exist
- which workloads run in `kube-system`
- where pods are scheduled

### 2. Inspect one workload deeply

Start with `kube-state-metrics`:

```bash
kubectl -n observability get deploy,po,svc
kubectl -n observability describe deployment kube-state-metrics
kubectl -n observability logs deploy/kube-state-metrics
kubectl -n observability get pod -o wide
```

What to notice:

- labels and selectors
- how the deployment owns the pod
- what service targets the pod
- how logs, readiness, and scheduling fit together

### 3. Compare `k9s` with `kubectl`

```bash
k9s
```

Good exercise:

- find the `kube-state-metrics` pod in `k9s`
- then repeat the same inspection with `kubectl get`, `describe`, and `logs`

### 4. Follow logs across pods

```bash
stern -n observability kube-state-metrics
```

This becomes more useful once multiple replicas or multiple services exist.

### 5. Render what the repo will apply

```bash
nix run .#render-observability
```

Then compare that with what is live:

```bash
kubectl get all -n observability -o yaml
```

This is one of the best ways to learn the difference between:

- desired state in Git
- rendered manifests
- live cluster state

### 6. Learn Helm without making Helm your primary interface

Useful commands:

```bash
helm show values prometheus-community/kube-state-metrics
helm template kube-state-metrics prometheus-community/kube-state-metrics
```

In this repository, Helm is used as a packaging source, while `Kustomize` owns
the repo structure.

### 7. Learn namespace and context switching

```bash
kubectx
kubens
kubens observability
kubectl get pods
```

## High-Value Commands To Practice

```bash
kubectl get events -A --sort-by=.lastTimestamp
kubectl describe node cluster-pi-01
kubectl top nodes
kubectl top pods -A
kubectl explain deployment.spec.template.spec.containers
kubectl api-resources
kubectl api-versions
```

## Best First Experiments

Safe early exercises:

1. scale `kube-state-metrics` up and back down
2. delete the pod and watch the deployment recreate it
3. inspect the resulting events, logs, and readiness changes
4. compare what Grafana and Prometheus show before and after

Example:

```bash
kubectl -n observability scale deployment kube-state-metrics --replicas=2
kubectl -n observability get pods -w
kubectl -n observability scale deployment kube-state-metrics --replicas=1
```

## What To Learn Next

After you are comfortable with the basics:

- services and selectors
- ingress and routing
- persistent volumes
- rolling updates
- failed pod debugging
- controller behavior for deployments, daemonsets, and statefulsets
- control-plane telemetry beyond `kube-state-metrics`
