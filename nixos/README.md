# NixOS Host Configuration

This directory contains the NixOS configuration for the five Raspberry Pi 4
cluster nodes. It is intentionally separate from `kubernetes/` — host concerns
(OS, k3s service, firewall, SSH) live here; in-cluster workloads live there.

---

## Layout

```
nixos/
  modules/     — shared NixOS modules imported by every node
  profiles/    — role-specific profiles composed onto base modules
  hosts/       — per-node configurations
```

### Modules

| Module | Purpose |
|--------|---------|
| `options.nix` | Declares all `homelab.*` NixOS options — the full option set is here |
| `base.nix` | Common OS baseline: locale, timezone, packages, users |
| `ssh.nix` | SSH daemon config; authorized keys wired from `homelab.adminAuthorizedKeys` |
| `k3s-common.nix` | k3s service config, CLI flags (Cilium CNI, metrics endpoints, CIDR) |
| `validation.nix` | Build-time assertions that catch missing required private values |

### Profiles

| Profile | Role |
|---------|------|
| `rpi4-base.nix` | Raspberry Pi 4 hardware support (nixos-hardware), kernel params |
| `k3s-server.nix` | Control-plane role — sets `homelab.cluster.nodeRole = "server"` |
| `k3s-agent.nix` | Worker role — sets `homelab.cluster.nodeRole = "agent"` |

### Hosts

Each file under `hosts/` is a thin per-node config that sets the hostname and
imports the appropriate server or agent profile. The public files use only
non-sensitive values; real SSH keys, tokens, and domain values come from the
private sibling flake.

`hosts/private/` contains example files and legacy override scaffolding — see
the README there.

---

## How Nodes Are Composed

The `flake.nix` helper `mkClusterModules` assembles each node's config by
layering modules in this order:

1. `nixos-hardware` Raspberry Pi 4 support
2. `options.nix`, `base.nix`, `ssh.nix`, `k3s-common.nix`, `validation.nix`
3. `rpi4-base.nix` profile
4. Role profile (`k3s-server.nix` or `k3s-agent.nix`)
5. Per-node hostname override
6. Private shared overrides (from `nix-cluster-private`)
7. Per-node private overrides (optional)

---

## Adding a Node

1. Create `nixos/hosts/<hostname>.nix` following the existing pattern.
2. Add a `nixosConfigurations.<hostname>` entry in `flake.nix`.
3. Add a matching entry to the private flake if the node needs custom values.
4. Validate: `nix run "path:$PWD#validate-private-config" -- <hostname>`.
