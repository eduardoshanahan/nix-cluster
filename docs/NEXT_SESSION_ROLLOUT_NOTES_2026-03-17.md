# Next Session Rollout Notes

## Fast Start

If starting fresh tomorrow, re-check only these facts first:

```bash
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.31 'hostname; systemctl is-active k3s; sudo k3s kubectl get nodes -o wide'
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.32 'hostname; systemctl is-active k3s'
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.33 'hostname; systemctl is-active k3s'
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.34 'hostname; systemctl is-active k3s'
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.35 'hostname; systemctl is-active k3s'
```

## Do Not Repeat These Dead Ends

Do not start by using:

```bash
nix run .#deploy-cluster-node -- cluster-pi-0N operator@192.0.2.3N
```

Reason:

- current helper does not handle `aarch64-linux` build-host requirements

Do not assume this will work either:

```bash
/run/current-system/sw/bin/nixos-rebuild switch \
  --flake path:/home/eduardo/Programming/gitea.<homelab-domain>/nix-cluster#cluster-pi-0N \
  --build-host operator@192.0.2.58 \
  --target-host operator@192.0.2.3N \
  --sudo
```

Reason:

- `rpi-box-01` is not signing its outputs today
- targets reject cross-host store copies because `require-sigs = true`

## Current Best-Known Tactic

For first conversion of a freshly flashed node, the fallback that works is:

```bash
NIX_SSHOPTS='-F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5' \
  /run/current-system/sw/bin/nixos-rebuild switch \
  --flake 'path:/home/eduardo/Programming/gitea.<homelab-domain>/nix-cluster#cluster-pi-0N' \
  --build-host operator@192.0.2.3N \
  --target-host operator@192.0.2.3N \
  --sudo
```

But expect:

- a very large first-time store copy
- slow first conversion

Then verify:

```bash
ssh -F /dev/null -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 operator@192.0.2.3N 'hostname; cat /etc/hostname; systemctl is-active k3s'
```

If hostname mismatch or stale cluster behavior appears:

1. reboot once
2. if still stale, wipe `/var/lib/rancher/k3s`
3. restart `k3s`

## `.32` Recovery Pattern That Worked

This sequence mattered:

1. deploy `cluster-pi-02`
2. observe `/etc/hostname = cluster-pi-02` but runtime behavior still stale
3. reboot
4. observe correct runtime hostname but stale `k3s` server behavior
5. wipe `/var/lib/rancher/k3s`
6. start `k3s`
7. verify join from `.31`

That is the best evidence we have for what may also be needed on `.33` to `.35`.
