# Session Status: Cilium Migration — 2026-04-19

## Goal

Replace Flannel with Cilium for NetworkPolicy enforcement (CKAD study).

## What Was Accomplished

### NixOS Configuration (DONE — committed)

`nixos/modules/k3s-common.nix` now includes on all server nodes:
- `--flannel-backend=none`
- `--disable-network-policy`

`nixos/modules/validation.nix` has assertions for both flags.

NixOS was deployed to all 5 nodes. The cluster was renamed during this process:
- pi-01/02/03 now show as `cluster-node-01/02/03` (were `cluster-pi-01/02/03`)
- pi-04/05 still show as `cluster-pi-04/05` (NixOS not yet deployed to workers)

### Cluster State (DONE — stable)

All 5 nodes are `Ready`:

```
cluster-node-01   Ready    control-plane,etcd
cluster-node-02   Ready    control-plane,etcd
cluster-node-03   Ready    control-plane,etcd
cluster-pi-04     Ready    <none>
cluster-pi-05     Ready    <none>
```

The cluster required a full etcd wipe and re-bootstrap after a tombstone file was
left when nodes were deleted during troubleshooting. Procedure:
1. `sudo systemctl stop k3s` on all 5 nodes
2. `sudo rm -rf /var/lib/rancher/k3s/server/db` on nodes 01–03 only
3. Start pi-01 first (bootstrap), wait for Ready, then start pi-02 + pi-03
4. Start pi-04 and pi-05 last

### Cilium Installation (DONE — partially working)

Cilium 1.16.19 is deployed via Helm from the pre-downloaded chart at
`kubernetes/platform/networking/cilium/charts/cilium-1.16.19/cilium/`.

```bash
helm install cilium \
  kubernetes/platform/networking/cilium/charts/cilium-1.16.19/cilium \
  --namespace kube-system \
  --values kubernetes/platform/networking/cilium/values.yaml
```

Current `values.yaml` settings:
- `kubeProxyReplacement: false` (k3s handles services)
- `ipam.mode: kubernetes`
- `envoy.enabled: false` (OOM on Pi 4 due to tcmalloc)
- `image.useDigest: false` (ARM64 multi-arch compatibility)
- VXLAN tunnel mode (default — native routing was tried and abandoned, see below)
- `bpf.enableTCX: false` (legacy TC hooks — TCX caused silent packet drops, see below)
- `policyEnforcementMode: default`

All 5 Cilium pods are `1/1 Running` with `Routing: Network: Tunnel [vxlan]` and
`Attach Mode: Legacy TC`.

**Pod-to-pod connectivity works** (tested: nettest on pi-05 can ping health endpoint
on cluster-node-01 via VXLAN).

## What Is NOT Working

### Pod-to-node-IP and Pod-to-service

Pods **cannot** reach node IPs (e.g., 192.168.1.31) or service ClusterIPs
(e.g., 10.43.0.1). This means:

- CoreDNS cannot reach the Kubernetes API → stays in CrashLoopBackOff
- `metrics-server` and `local-path-provisioner` also CrashLoopBackOff for the
  same reason (cannot bootstrap without API access)
- The cluster's system pods are all broken

Symptom: Cilium monitor shows `-> stack` for the traffic (Cilium passes it to the
kernel stack), but the packet never appears on any interface via tcpdump, and
iptables LOG rules in PREROUTING/INPUT/FORWARD/OUTPUT show zero matches.

Conclusion: Cilium's `-> stack` delivery via `bpf_redirect(CILIUM_HOST_IFINDEX)`
bypasses the standard netfilter hooks entirely. The `cil_to_host` BPF program on
the `cilium_host` interface is absorbing or dropping packets destined for external
IPs rather than forwarding them through iptables for service DNAT.

## Root Causes Investigated (with Findings)

### Cilium 1.17.x BPF compilation bug

**Confirmed.** Cilium 1.17.x on kernel 6.12 produces `CALLS_MAP` macro
redefinition errors in node_config.h vs ep_config.h, making all Cilium pods
crash immediately.

**Fix:** Downgraded to 1.16.19.

### cilium_vxlan device conflict

**Confirmed.** Cilium 1.16.x crashes on startup if a stale `cilium_vxlan` device
exists from a prior run (`RTNETLINK answers: File exists`).

**Root cause:** CrashLoopBackOff cycle leaves the VXLAN device behind on each
restart because cleanup happens only on clean shutdown.

**Fix tried (failed):** Native routing mode (`routingMode: native`) to avoid VXLAN
entirely. This caused silent pod egress failure (see below).

**Actual fix:** Fresh cluster wipe + etcd re-bootstrap → no stale devices.
Now using VXLAN mode on a clean cluster without this problem.

### Native routing mode — pod egress completely broken

**Confirmed dead end.** `routingMode: native` with `autoDirectNodeRoutes: true`
was tried to avoid the VXLAN device issue. All Cilium pods started successfully
and BPF compiled. But all pod egress was silently broken:
- Pods couldn't reach their own gateway (cilium_host IP)
- Cilium monitor showed packets going `-> stack`
- tcpdump on every interface showed packets arriving at the lxc interface but
  never appearing anywhere else
- Kernel 6.12.47 on RPi 4

This appeared to be a kernel/Cilium interaction specific to native routing mode
on this hardware+kernel combination. Not investigated further.

### TCX (TC eXpress) attach mode — also broken

**Confirmed.** With TCX attach mode (Cilium default on kernel ≥ 5.15):
- Same silent pod egress failure as native routing mode
- Cilium monitor shows `-> stack` but packets never arrive
- iptables LOG rules confirm zero packet matches in PREROUTING/FORWARD/OUTPUT/INPUT

**Fix:** `bpf.enableTCX: false` in values.yaml forces legacy TC (clsact mode).
After this change, pod-to-pod via VXLAN works correctly.

BUT: pod-to-node-IP and pod-to-service STILL fails even with legacy TC + VXLAN.
This is the remaining open issue.

### Likely remaining cause: `hostLegacyRouting`

The Cilium helm chart has a `hostLegacyRouting: ~` (null/unset) option. Based on
investigation, `-> stack` delivery bypasses the KUBE-SERVICES iptables chain that
performs service DNAT. Setting `hostLegacyRouting: true` may force Cilium to use
the older host routing path that properly goes through netfilter.

**This was the next thing to try when the session was stopped.**

## Next Steps

1. **Add `hostLegacyRouting: true` to values.yaml and re-deploy Cilium.**

   ```yaml
   # In values.yaml, under the bpf section:
   bpf:
     enableTCX: false
     hostLegacyRouting: true  # <-- try this
   ```

   Then:
   ```bash
   helm upgrade cilium \
     kubernetes/platform/networking/cilium/charts/cilium-1.16.19/cilium \
     --namespace kube-system \
     --values kubernetes/platform/networking/cilium/values.yaml
   kubectl -n kube-system rollout restart daemonset/cilium
   ```

2. **Verify with:**
   ```bash
   kubectl exec nettest -- ping -c 3 192.168.1.31
   kubectl exec nettest -- nc -w 3 10.43.0.1 443 && echo connected
   ```

3. **If that works, restart the crashing system pods:**
   ```bash
   kubectl -n kube-system delete pod -l k8s-app=kube-dns
   kubectl -n kube-system delete pod -l app=local-path-provisioner
   kubectl -n kube-system delete pod -l k8s-app=metrics-server
   ```

4. **Verify CoreDNS is healthy:**
   ```bash
   kubectl -n kube-system get pods
   kubectl exec nettest -- nslookup kubernetes.default.svc.cluster.local
   ```

5. **Run NetworkPolicy enforcement test** (the original goal):
   ```bash
   kubectl create ns netpol-test
   # two pods + deny-all + selective allow
   kubectl delete ns netpol-test
   ```

6. **Deploy NixOS to worker nodes (pi-04, pi-05)** to rename them to
   `cluster-node-04/05`. Not required for CKAD study but keeps naming consistent.

7. **Commit values.yaml changes** once networking is verified.

## Files Changed This Session

| File | Change |
|------|--------|
| `nixos/modules/k3s-common.nix` | Added `--flannel-backend=none`, `--disable-network-policy`, TCP port 4240 |
| `nixos/modules/validation.nix` | Added assertions for both new flags |
| `kubernetes/platform/networking/cilium/kustomization.yaml` | Version pinned to 1.16.19 |
| `kubernetes/platform/networking/cilium/values.yaml` | Multiple iterations; current state is VXLAN + legacy TC |

## Kubeconfig Access

The kubeconfig is at `/etc/rancher/k3s/k3s.yaml` on pi-01 (192.168.1.31).
To use from dev machine:

```bash
ssh eduardo@192.168.1.31 "sudo cat /etc/rancher/k3s/k3s.yaml" \
  | sed 's|https://127.0.0.1:6443|https://192.168.1.31:6443|' \
  > /tmp/k3s-kubeconfig.yaml
nix develop --command kubectl --kubeconfig /tmp/k3s-kubeconfig.yaml get nodes
```

The nix devshell in `nix-cluster/` includes `helm` and `kubectl`.
