# Cilium CNI on ARM64 k3s — Investigation and Resolution

## Context

Cluster: 5 Raspberry Pi 4 nodes (ARM64, kernel 6.12), k3s v1.35.2+k3s1 HA setup,
3 control-plane nodes (cluster-pi-01/02/03), 2 workers (cluster-pi-04/05).
All nodes on 192.168.1.0/24 L2 subnet.

## Problem 1: All ClusterIP routing broken (kubeProxyReplacement: false)

### Symptom

With `kubeProxyReplacement: false` (Cilium default partial mode), pod-to-pod worked
but pod-to-ClusterIP timed out. Also, Traefik (running in hostNetwork) could not
reach ClusterIP backends — MetalLB controller and other pods using the kubernetes
Service API all failed.

### Root cause

Cilium's BPF TC hooks attach to every network device and intercept packets before
iptables processes them. When `kubeProxyReplacement: false`, Cilium delegates
ClusterIP DNAT to iptables PREROUTING KUBE-SERVICES. But because Cilium's TC hooks
run first and move packets through the BPF datapath, iptables PREROUTING KUBE-SERVICES
sees 0 hits — it never fires. POSTROUTING MASQUERADE similarly gets 0 hits, so pod
egress SNAT doesn't work either.

Confirmed with:
```
iptables -t nat -L KUBE-SERVICES -nv   # 0 pkts, 0 bytes — chain never fires
```

### Fix

Enable full Cilium kube-proxy replacement:

```yaml
# cilium values.yaml
kubeProxyReplacement: true
k8sServiceHost: cluster-api.hhlab.home.arpa
k8sServicePort: 6443
```

`k8sServiceHost`/`k8sServicePort` are required because Cilium needs to reach the
API server directly (by physical IP/DNS) during bootstrap before ClusterIP routing
is active — without these, Cilium hangs on startup waiting for a ClusterIP that it
hasn't yet configured.

Also add `--disable-kube-proxy` to k3s server flags to prevent k3s from running its
embedded kube-proxy (which would conflict):

```nix
# nixos/modules/k3s-common.nix
serverOnlyFlags = [
  ...
  "--disable-kube-proxy"
  ...
];
```

After this fix: `kubectl exec` into any pod → `nc -zv 10.43.0.1 443` → open.
Cilium Socket LB (cgroup/connect4 hook) intercepts the connect syscall and rewrites
to a real backend before any packet is sent.

---

## Problem 2: Host→pod SNAT breaks liveness probes (endpointRoutes missing)

### Symptom

After enabling `kubeProxyReplacement: true`, pods could reach ClusterIPs, but
the kubelet liveness/readiness probes from the host failed with timeouts. Example:

```
Get "http://10.42.5.66:7472/metrics": context deadline exceeded
```

### Root cause

With kube-proxy replacement enabled, a `cil_from_host` BPF TC egress hook fires on
`cilium_host` when the host sends traffic to a pod IP. This hook SNATs the source IP:

- Before SNAT: source = `192.168.1.34` (host IP), dest = `10.42.5.66` (pod IP)
- After SNAT: source = `10.42.5.216` (cilium_host IP), dest = `10.42.5.66`

But `cil_from_host` creates no reverse NAT entry (`RevNAT=0` in CT table). When the
pod replies to `10.42.5.216:ephemeral_port`, the kernel looks for a NAT entry to
de-NAT it back to `192.168.1.34` — finds none — and the kubelet never receives the
reply.

Confirmed with:
```
# Inside Cilium pod on cluster-pi-04:
cilium-dbg bpf ct list global | grep "10.42.5.66"
# Shows: RevNAT=0 for all CT entries for pod IP → no reverse translation
```

### Failed attempts

- `bpf.masquerade: true` — this controls egress masquerade for pod→external, not
  host→pod. No effect on cil_from_host SNAT. Reverted.
- `routingMode: native + autoDirectNodeRoutes` — eliminates VXLAN encapsulation,
  but `cil_from_host` SNAT is not tunnel-specific. Still present. Kept (needed for
  other reasons, see Problem 3 note).

### Fix

Enable per-endpoint routes:

```yaml
# cilium values.yaml
endpointRoutes:
  enabled: true
```

This installs a `/32` host route via the pod's lxc veth for each pod:

```
10.42.5.66 dev lxc8cc293edfb14 proto kernel scope link
```

Host→pod traffic now goes directly via the lxc veth without touching `cilium_host`
or `cil_from_host`, so no SNAT occurs and replies route correctly.

Confirmed fix: `ping -c3 10.42.5.66` from host succeeds. Liveness probes pass.

---

## Problem 3: TCX attach mode absorbs packets (kernel 6.12)

### Symptom

With `bpf.enableTCX: true` (default in Cilium 1.16+), pods could not communicate
with anything. Cilium monitor showed `-> stack` for all ingress from container, but
tcpdump saw no traffic.

### Root cause

TCX (TC eXpress) uses BPF links instead of clsact qdisc filters. On Linux kernel
6.12.47 on Raspberry Pi 4, TCX appears to absorb packets silently — they enter
`cil_from_container` but are not forwarded.

This is a kernel/hardware-specific incompatibility. Not reproduced on x86_64.

### Fix

```yaml
bpf:
  enableTCX: false
```

This falls back to legacy TC clsact mode, which works correctly on kernel 6.12.

---

## Problem 4: metrics-server can't scrape kubelet (port 10250 blocked)

### Symptom

`metrics-server` stayed `0/1 Running` with repeated errors:

```
Failed to scrape node: Get "https://192.168.1.31:10250/metrics/resource":
context deadline exceeded
```

### Root cause

The NixOS firewall (`networking.firewall`) was not opening port 10250 (kubelet API).
The metrics-server needs direct HTTPS access to kubelet on each node's physical IP
to collect CPU/memory usage.

### Fix

```nix
# nixos/modules/k3s-common.nix
allowedTCPPorts = [
  ...
  10250  # kubelet API — required by metrics-server
  ...
];
```

Deployed to all 5 nodes. metrics-server became `1/1 Running` immediately after.

---

## ARM64-specific Cilium settings

These are required for Raspberry Pi 4 nodes — not just general cluster config:

| Setting | Value | Reason |
|---------|-------|--------|
| `envoy.enabled` | `false` | Envoy DaemonSet OOM-crashes on 4GB RAM (tcmalloc requires 1GB aligned mmap) |
| `bpf.enableTCX` | `false` | Packets absorbed silently on kernel 6.12 ARM64 |
| `image.useDigest` | `false` | Multi-arch images: digest pinning doesn't resolve ARM64 variant |
| `operator.image.useDigest` | `false` | Same reason |
| `routingMode` | `native` | All nodes on L2 — no VXLAN needed; also avoids cil_from_host SNAT in VXLAN mode |
| `autoDirectNodeRoutes` | `true` | Programs per-node pod subnet routes via physical interface |
| `ipv4NativeRoutingCIDR` | `10.42.0.0/16` | Pod CIDR for native routing masquerade exclusion |
| `endpointRoutes.enabled` | `true` | Per-pod /32 routes bypass cil_from_host SNAT |
| `kubeProxyReplacement` | `true` | Required for ClusterIP routing to work at all (iptables hooks bypassed) |

---

## Diagnostic commands used

```bash
# Verify ClusterIP is in Cilium's BPF service map:
kubectl exec -n kube-system <cilium-pod> -- cilium-dbg service list

# Check Socket LB status (should show Enabled, Full coverage):
kubectl exec -n kube-system <cilium-pod> -- cilium-dbg status --verbose | grep -A10 "KubeProxyReplacement"

# Check host→pod SNAT (RevNAT=0 means no reverse translation):
kubectl exec -n kube-system <cilium-pod> -- cilium-dbg bpf ct list global | grep <pod-ip>

# Verify per-endpoint routes are installed:
ssh cluster-pi-04 'ip route show | grep "10.42"'
# Should see: 10.42.5.XX dev lxcXXX proto kernel scope link

# Test pod-to-ClusterIP:
kubectl exec <pod> -- nc -zv 10.43.0.1 443

# Test pod-to-host port (e.g. kubelet):
kubectl exec <pod> -- nc -zv 192.168.1.31 10250
```

---

## Final working state

All 5 nodes Ready, all platform pods `1/1 Running`:
- Cilium (all nodes)
- CoreDNS
- metrics-server
- MetalLB controller + speakers
- Traefik (2 replicas, `192.168.1.36` assigned by MetalLB)
- kube-state-metrics
- apiserver-metrics-proxy
- local-path-provisioner
