# Node Deployment Runbook

Procedures for deploying NixOS to cluster nodes and recovering from join failures.

## Fast Health Check

Before starting any node work, verify the cluster is healthy:

```bash
export NIX_CLUSTER_IDENTITY_FILE="${NIX_CLUSTER_IDENTITY_FILE:-$HOME/.ssh/operator_ed25519}"

for ip in 192.0.2.31 192.0.2.32 192.0.2.33 192.0.2.34 192.0.2.35; do
  ssh -i "$NIX_CLUSTER_IDENTITY_FILE" -F /dev/null \
    -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new \
    -o BatchMode=yes -o ConnectTimeout=5 \
    operator@$ip 'hostname; systemctl is-active k3s'
done

ssh -i "$NIX_CLUSTER_IDENTITY_FILE" -F /dev/null \
  -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new \
  -o BatchMode=yes -o ConnectTimeout=5 \
  operator@192.0.2.31 'sudo k3s kubectl get nodes -o wide'
```

Expected: all 5 nodes report their correct hostname, k3s `active`, all `Ready`.

## Standard Deploy

Use the repo deploy helper with a remote ARM builder (`pi-node-a` at `192.0.2.58`):

```bash
export NIX_CLUSTER_IDENTITY_FILE="${NIX_CLUSTER_IDENTITY_FILE:-$HOME/.ssh/operator_ed25519}"

NIX_CLUSTER_BUILD_HOST="operator@192.0.2.58" \
NIX_CLUSTER_SSHOPTS="-i $NIX_CLUSTER_IDENTITY_FILE -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5" \
  nix run .#deploy-cluster-node -- cluster-pi-0N operator@192.0.2.3N
```

Do not use plain `nixos-rebuild` directly — the repo helper sets the correct SSH options and builder flow.

## Builder Trust Checklist

Before relying on the cross-host build path, verify on `pi-node-a`:

```bash
ssh -i "$NIX_CLUSTER_IDENTITY_FILE" -F /dev/null \
  -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new \
  -o BatchMode=yes -o ConnectTimeout=5 \
  operator@192.0.2.58 \
  'sudo nix config show | grep -E "require-sigs|secret-key-files|trusted-public-keys"'
```

Required:
- `require-sigs = true`
- `secret-key-files` set on `pi-node-a`
- Matching public key in `homelab.nix.trustedBuilderPublicKeys` for cluster nodes

## Recovery Fallback (self-build)

If builder trust is not ready or a node needs isolated first-conversion:

```bash
nix run .#deploy-cluster-node -- --self-build cluster-pi-0N operator@192.0.2.3N
```

Expect a slow first run (large store copy). After deploy, verify:

```bash
ssh -i "$NIX_CLUSTER_IDENTITY_FILE" -F /dev/null \
  -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new \
  -o BatchMode=yes -o ConnectTimeout=5 \
  operator@192.0.2.3N 'hostname; cat /etc/hostname; systemctl is-active k3s'
```

## Control-Plane Node Recovery

If a control-plane node shows wrong identity or stale cluster behavior after deploy:

1. Deploy the intended config
2. Verify `/etc/hostname` changed
3. Reboot
4. If still showing stale embedded-cluster behavior: `sudo rm -rf /var/lib/rancher/k3s`
5. `sudo systemctl start k3s`
6. Verify join from `cluster-pi-01`: `sudo k3s kubectl get nodes`

## Worker Node Recovery

If a worker is rejected for duplicate hostname or mismatched node password:

1. Deploy the worker config
2. Reboot
3. If worker still rejected: `sudo systemctl stop k3s`
4. `sudo rm -rf /var/lib/rancher/k3s`
5. `sudo rm -f /etc/rancher/node/password`
6. `sudo systemctl start k3s`
7. Verify join from `cluster-pi-01`

Both locations must be wiped together — wiping only `/var/lib/rancher/k3s` is not always sufficient for workers.
