# API Server Metrics Proxy

This component is the first control-plane observability prototype.

Purpose:

- authenticate to the Kubernetes API server from inside the cluster
- fetch `/metrics` using a service account with explicit RBAC
- re-expose those metrics as a normal Prometheus endpoint inside the
  `observability` namespace

Current scope:

- internal `ClusterIP` service plus Traefik ingress exposure on the existing
  `kube-state-metrics` host
- external path: `https://kube-state-metrics.<lab-domain>/apiserver-metrics`
- no sibling-repo Prometheus integration yet

This keeps the first slice focused on proving the cluster-side auth and
collection model before expanding scrape inventory or dashboards elsewhere.
