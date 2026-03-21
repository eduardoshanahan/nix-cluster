# Session Status: 2026-03-21

## Purpose

This document is the fresh-session handoff after reviewing the live cluster,
the `nix-cluster` repository, and the related monitoring ownership in
`nix-pi` and `nix-services`.

The main goal of this session was not to add new workloads. It was to replace
assumptions with verified facts before continuing platform work.

This document is intended to let the next session start immediately with the
current ground truth.

## What Was Verified Live

### Cluster shape

From the control plane, the cluster is healthy and currently has:

- `cluster-pi-01`, `cluster-pi-02`, `cluster-pi-03` as control-plane nodes
- `cluster-pi-04`, `cluster-pi-05` as workers
- all five nodes `Ready`

### Namespaces

The live namespaces are:

- `default`
- `headlamp`
- `kube-node-lease`
- `kube-public`
- `kube-system`
- `metallb-system`
- `observability`
- `traefik`

### Live workloads

The cluster is intentionally small. The live workload set is:

- `coredns`
- `local-path-provisioner`
- `metrics-server`
- `metallb-controller`
- `metallb-speaker`
- `traefik`
- `headlamp`
- `kube-state-metrics`

### Live services and exposure

The important live services are:

- Kubernetes API:
  - internal service `default/kubernetes` as `ClusterIP`
- `traefik/traefik`:
  - `LoadBalancer`
  - external IP `192.0.2.36`
  - ports `80` and `443`
- `observability/kube-state-metrics`:
  - `NodePort`
  - `8080:30080/TCP`
- `headlamp/headlamp`:
  - `ClusterIP`
  - port `80`

### Live ingress

The important live ingress is:

- `headlamp.<homelab-domain>`
  - address `192.0.2.36`
  - class `traefik`

### Live MetalLB

MetalLB is already active in the cluster.

Verified live:

- `IPAddressPool`:
  - `metallb-system/homelab-lan`
  - addresses `192.0.2.36-192.0.2.40`
- `L2Advertisement`:
  - `metallb-system/homelab-lan`

## Important Repo And Live Drift

This is the most important finding of the session.

The live cluster is ahead of the current `nix-cluster` repository shape.

### 1. Traefik is already deployed live

But `nix-cluster` does not yet contain a Traefik workload tree under
`kubernetes/platform/`.

That means:

- the March 20 documentation recommendation to add Traefik is already true in
  live cluster state
- but it is not yet reflected in repo-managed manifests in `nix-cluster`

### 2. MetalLB is already deployed live

But `nix-cluster` currently does not contain repo-managed MetalLB manifests.

That means:

- live cluster networking depends on MetalLB already
- but the repo is not yet the source of truth for it

### 3. Headlamp is different in repo vs live

In `nix-cluster`, Headlamp currently renders as:

- `NodePort`
- TCP `30081`

Relevant repo files:

- `kubernetes/operations/headlamp/values.yaml`
- `kubernetes/operations/headlamp/README.md`

But live cluster state shows:

- Headlamp service is `ClusterIP`
- Headlamp is exposed through Traefik ingress
- `headlamp.<homelab-domain>` already routes to `192.0.2.36`

This means the repo currently models an outdated exposure shape.

### 4. `kube-state-metrics` is still exposed as raw NodePort

This is live and repo-aligned today:

- `NodePort` `30080`
- currently scraped externally by Prometheus

But the new live cluster networking makes that shape a temporary bridge rather
than the final target.

## Cross-Repo Monitoring Ownership

### `nix-cluster`

Currently owns cluster-side telemetry production and host-side exposure on the
Pi nodes:

- `node_exporter` on every cluster Pi
- firewall openings for cluster node metrics and NodePorts
- Kubernetes manifests for `kube-state-metrics`
- Kubernetes manifests for Headlamp, though currently stale relative to live
  service exposure

Important files:

- `nixos/modules/base.nix`
- `nixos/modules/k3s-common.nix`
- `kubernetes/platform/observability/kube-state-metrics/values.yaml`
- `kubernetes/operations/headlamp/values.yaml`

### `nix-pi`

Owns the monitoring hub on `rpi-box-02`.

This is the current source of truth for:

- Prometheus scrape target inventory
- Uptime Kuma desired monitor inventory
- host-specific monitoring routes and direct checks

Important file:

- `nix-pi/nixos/hosts/private/rpi-box-02.nix`

Relevant verified facts from that file:

- cluster node exporters are scraped as
  `cluster-pi-0N-metrics.<domain>:9100`
- `kube-state-metrics` scrape target was previously
  `cluster-pi-01.<domain>:30080`
- Uptime Kuma also monitors:
  - cluster API on `cluster-api.<domain>:6443`
  - SSH on all five Pis
  - all five cluster node exporters
  - `kube-state-metrics`

### `nix-services`

Owns the reusable monitoring service modules and Grafana dashboards.

Important files:

- `nix-services/services/prometheus/config-text.nix`
- `nix-services/services/prometheus/options.nix`
- `nix-services/services/grafana/dashboards.nix`

Relevant verified facts:

- Prometheus has a dedicated `kube-state-metrics` job
- Grafana already includes Kubernetes dashboards that depend on
  `job="kube-state-metrics"`
- Grafana already includes cluster Pi host dashboards using the shared
  `job="nodes"` scrape model

## What Was Changed In This Session

Two repo changes were made intentionally.

### 1. Close kubelet port `10250` in `nix-cluster`

File changed:

- `nix-cluster/nixos/modules/k3s-common.nix`

Reason:

- no current scrape dependency for kubelet metrics was found in `nix-pi` or
  `nix-services`
- keeping it open added exposure without a verified use case

Current evaluated cluster firewall ports for a control-plane node are now:

- `22`
- `2379`
- `2380`
- `6443`
- `9100`
- `9345`
- `30080`
- `30081`

### 2. Point `kube-state-metrics` scrape target at `cluster-api`

File changed:

- `nix-pi/nixos/hosts/private/rpi-box-02.nix`

Change made:

- from `cluster-pi-01.<domain>:30080`
- to `cluster-api.<domain>:30080`

Reason:

- this decouples the monitoring config from the literal node name
- it still works with the current DNS
- it is a better transitional target while the service is still NodePort-based

Verified live:

- `http://cluster-api.<homelab-domain>:30080/metrics` is currently reachable

### 3. Documentation updates for multi-operator SSH identity usage

Earlier in the session, docs were updated to stop assuming a specific
workstation SSH key path.

Files changed:

- `nix-cluster/docs/SESSION_STATUS_2026-03-17.md`
- `nix-cluster/docs/SESSION_STATUS_2026-03-18.md`
- `nix-cluster/docs/NEXT_SESSION_ROLLOUT_NOTES_2026-03-17.md`

These docs now use `NIX_CLUSTER_IDENTITY_FILE` instead of a hardcoded
`thinkpad_ed25519` path.

### 4. Temporary inspection leftovers were cleaned up

The temporary `kubectl debug` pods created during investigation were deleted.

Verified result:

- `default` namespace is clean again

## Current DNS Reality

At the time of this handoff:

- `cluster-api.<homelab-domain>` resolves to `192.0.2.31`

Important interpretation:

- there is already a cluster load balancer in the environment
- but it is for Traefik ingress on `192.0.2.36`
- it is **not** currently a load-balanced frontend for the Kubernetes API

So:

- `cluster-api` still effectively points at `cluster-pi-01`
- `cluster-api:30080` currently works only because that DNS record points to
  `.31`
- it should not be assumed that `cluster-api` is already a true HA frontend
  for the Kubernetes API or for arbitrary NodePorts

## Recommended End State

The long-term direction from this session is:

1. no unnecessary cluster node ports open
2. no raw telemetry NodePorts left open unless truly indispensable
3. Prometheus and Kuma consume cluster telemetry through intentional stable
   frontends
4. the repo becomes the source of truth again for the cluster networking stack
5. DNS names reflect deliberate frontends, not accidental historical node
   anchoring

In practical terms, the desired end state is:

- `10250` remains closed
- `node_exporter` remains enabled on `9100` only if the monitoring topology
  still requires direct host scraping
- `kube-state-metrics` stops using NodePort `30080`
- Headlamp stops being represented as NodePort in repo state
- `30081` is closed unless a real live dependency still needs it
- `kube-state-metrics` is scraped through Traefik on an internal hostname
- `nix-cluster` gains repo-managed Traefik and MetalLB resources, or at
  minimum documents the live/manual drift explicitly until they are imported
- a deliberate decision is made about whether `cluster-api` should:
  - remain the Kubernetes API name only
  - or become a true HA frontend later through a real API load balancer

## Recommended Implementation Sequence

This sequence is designed to reduce risk to the rest of the homelab while
allowing the cluster side to change freely.

### Phase 1: Align repo with current live cluster truth

Do this before changing more exposure.

#### `nix-cluster`

1. Update Headlamp manifests to match the actual intended shape:
   - service should be `ClusterIP`
   - ingress should be modeled in repo
   - remove stale NodePort assumptions from:
     - `kubernetes/operations/headlamp/values.yaml`
     - `kubernetes/operations/headlamp/README.md`
2. Add the currently live Headlamp ingress resources into repo ownership.
3. Decide whether the repo should import the live Traefik deployment now or
   document it as an external/manual platform dependency temporarily.
4. Decide whether the repo should import the live MetalLB deployment now or
   document it as an external/manual platform dependency temporarily.

Why this phase matters:

- if the next session applies repo state blindly, Headlamp could regress from
  ingress-backed `ClusterIP` back to NodePort
- the current repo/live mismatch is the largest hidden footgun

### Phase 2: Move `kube-state-metrics` off NodePort

This is the next telemetry hardening step.

#### `nix-cluster`

1. Change `kubernetes/platform/observability/kube-state-metrics/values.yaml`:
   - service from `NodePort` to `ClusterIP`
2. Add ingress for `kube-state-metrics` through Traefik.
3. Choose an internal hostname, for example:
   - `kube-state-metrics.<homelab-domain>`
   - or another clearly internal observability FQDN
4. Prefer TLS termination through Traefik if consistent with current cluster
   ingress practice.
5. Update `kubernetes/platform/observability/README.md` to replace the stale
   `NodePort 30080` assumption.

#### `nix-pi`

1. Update Prometheus scrape target from `cluster-api:30080` to the new routed
   internal hostname.
2. Update Uptime Kuma monitor target from raw `30080` to the new routed
   hostname if continuing to monitor that endpoint directly.

#### `nix-services`

No dashboard changes should be necessary if the Prometheus job name remains:

- `kube-state-metrics`

Why this phase matters:

- it removes the main remaining raw telemetry NodePort
- it stops coupling cluster telemetry to a specific control-plane node
- it makes cluster metrics exposure consistent with the already-live Traefik
  ingress model

### Phase 3: Close leftover cluster ports that are no longer needed

After Phase 2 is live and verified:

#### `nix-cluster`

1. Remove `30080` from cluster firewall openings.
2. Verify whether `30081` is still needed.

Important caution about `30081`:

- repo currently says Headlamp uses NodePort `30081`
- live cluster currently does **not** use that exposure shape
- do not close `30081` until repo and live Headlamp configuration are aligned
  and redeployed

Expected outcome:

- cluster firewall should keep only indispensable ports
- no leftover monitoring NodePorts should remain open by habit

### Phase 4: Decide the future of `cluster-api`

This is a separate concern from metrics hardening.

Do not conflate it with Traefik ingress.

Questions to answer later:

1. Should `cluster-api.<homelab-domain>` remain pointed at `.31` for now?
2. Should it become a real HA API endpoint?
3. If yes, what should provide that?
   - `kube-vip`
   - dedicated TCP load balancer
   - some other control-plane-safe frontend

Important rule:

- do **not** point `cluster-api` at the existing Traefik `LoadBalancer`
  address `192.0.2.36` unless a deliberate TCP API frontend is implemented
  there for `6443`

## Validation Checklist For The Next Session

Use these checks after each phase.

### Cluster inventory checks

```bash
ssh -i "$NIX_CLUSTER_IDENTITY_FILE" -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.32 \
  'sudo k3s kubectl get nodes -o wide; echo; sudo k3s kubectl get deploy,ds,svc,ingress -A -o wide'
```

### Verify `kube-state-metrics` exposure

Current transitional check:

```bash
curl -fsS http://cluster-api.<homelab-domain>:30080/metrics | sed -n '1,10p'
```

Future intended check after ingress migration:

```bash
curl -fsS https://<new-kube-state-metrics-hostname>/metrics | sed -n '1,10p'
```

### Verify cluster node metrics

```bash
for host in cluster-pi-01 cluster-pi-02 cluster-pi-03 cluster-pi-04 cluster-pi-05; do
  curl -fsS "http://${host}-metrics.<homelab-domain>:9100/metrics" >/dev/null
done
```

### Verify Prometheus scrape health

Run on `rpi-box-02` after `nix-pi` deploy:

```bash
sudo docker exec prometheus wget -qO- \
  'http://127.0.0.1:9090/api/v1/targets'
```

Check specifically:

- job `nodes`
- job `kube-state-metrics`

### Verify Kuma health

Confirm these cluster monitors remain healthy:

- `Cluster API`
- `SSH cluster-pi-01` through `SSH cluster-pi-05`
- `Node Exporter cluster-pi-01` through `Node Exporter cluster-pi-05`
- `kube-state-metrics`

## Files Most Likely To Change Next

### `nix-cluster`

- `nixos/modules/k3s-common.nix`
- `kubernetes/platform/observability/README.md`
- `kubernetes/platform/observability/kube-state-metrics/values.yaml`
- `kubernetes/platform/observability/kube-state-metrics/`
- `kubernetes/operations/headlamp/README.md`
- `kubernetes/operations/headlamp/values.yaml`
- new Traefik and possibly MetalLB repo-managed resources if imported

### `nix-pi`

- `nixos/hosts/private/rpi-box-02.nix`

### `nix-services`

Maybe none for the next immediate step.

Possible future updates only if:

- Prometheus scrape job behavior needs adjustment
- or Grafana should surface the new routed telemetry endpoint differently

## Do Not Start The Next Session With These Broken Assumptions

These assumptions are now known to be wrong:

1. "Traefik is the next thing to add to the cluster."
   False. Traefik is already deployed live.

2. "MetalLB is still future work."
   False. MetalLB is already deployed live.

3. "Headlamp is currently a NodePort service in practice."
   False. Live Headlamp is `ClusterIP` behind Traefik ingress.

4. "`cluster-api` is already a true load-balanced API endpoint."
   False. It currently resolves to `.31`.

5. "The repo fully describes current cluster networking."
   False. The live cluster networking stack is ahead of repo ownership.

## Working Rule

We may read sibling repositories for context.

We may edit them when the user explicitly asks us to make the coordinated
cross-repo change.
