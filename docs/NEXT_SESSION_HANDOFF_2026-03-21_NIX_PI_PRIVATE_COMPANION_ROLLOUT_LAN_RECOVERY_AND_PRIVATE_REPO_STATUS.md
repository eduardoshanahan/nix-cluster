# Next Session Handoff: 2026-03-21 `nix-pi` Companion Rollout, `rpi-box-02` LAN Recovery, And Private Repo Status

## Purpose

This document is the clean restart point for the work that:

- finished the `nix-pi` public/private companion-repo migration
- verified and committed the public `nix-pi` changes
- finished and committed the local `nix-pi-private` repo
- diagnosed why `rpi-box-02` lost normal LAN SSH access after the migration work
- proved that the breakage was a runtime configuration issue on `rpi-box-02`
- fixed that breakage with a targeted redeploy
- restored normal LAN access to `rpi-box-02`
- prepared the newly-created Gitea private remote for `nix-pi-private`

Use this document to avoid re-investigating:

- why `rpi-box-02` became unreachable over normal LAN SSH
- which findings were red herrings versus real root cause
- which commits already exist in each repo
- what still remains to be pushed or created
- how to resume the broader companion-repo migration work in the next session

## Executive Summary

At the end of this session:

- normal LAN reachability to `rpi-box-02` was restored
- `ssh eduardo@rpi-box-02` from `meganix` works again
- the key runtime fault was on `rpi-box-02`, not `meganix`
- `rpi-box-02` was still running an older Tailscale container config that:
  - advertised `192.168.1.0/24`
  - accepted routes
- that older live Tailscale config injected:
  - `192.168.1.0/24 dev tailscale0 table 52`
- NixOS reverse-path filtering on `rpi-box-02` then dropped normal LAN packets
  before they reached `sshd`
- a targeted `rpi-box-02` redeploy using the updated local `nix-pi-private`
  config removed the bad live Tailscale args
- after that redeploy:
  - `ping 192.168.1.59` from `meganix` succeeded
  - `ssh eduardo@rpi-box-02` from `meganix` succeeded
  - `ping 192.168.1.59` from `rpi-box-01` succeeded

The main practical result is:

- `nix-pi` migration is complete enough to move on
- `rpi-box-02` is back on the normal LAN path
- `nix-pi-private` now carries the latest intended Tailscale behavior that had
  landed later in public `nix-pi`

## Important Repos And Current Meaning

### 1. Public `nix-pi`

Path:

- `/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi`

Role now:

- public flake
- tracked placeholder private input
- thin public host identity
- public docs
- public encrypted SOPS artifacts under `secrets/`

### 2. Real private `nix-pi-private`

Path:

- `/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi-private`

Role now:

- real private host modules
- real private shared module
- consumes public repo path through `piRepoRoot`
- now also contains the latest Tailscale-related fixes and safeguards for:
  - `rpi-box-01`
  - `rpi-box-02`
  - `rpi-box-03`

### 3. Local machine config

Path:

- `/home/eduardo/nix`

Role in this session:

- permanent ARP hardening for `meganix`

Important note:

- this helped remove ARP ambiguity on `meganix`
- but it was not the root cause of the SSH outage
- the decisive root cause was still on `rpi-box-02`

## The `rpi-box-02` Failure: What Happened

### Initial symptom

After the `nix-pi` migration and the Tailscale restore on `rpi-box-02`:

- `tailscale.service` started successfully during activation
- but normal SSH checks to `rpi-box-02` timed out

Later reproduction showed:

- from `meganix`:
  - `ssh eduardo@rpi-box-02` timed out
  - `ping 192.168.1.59` failed
  - HTTP probes to `192.168.1.59:9100` failed
- from `rpi-box-01`:
  - `ping 192.168.1.59` failed
  - `ssh eduardo@rpi-box-02` timed out

So this was not only a `meganix` issue.

### What still worked during the outage

During the outage:

- `tailscale ping rpi-box-02` worked from `meganix`
- Tailscale-recovered SSH worked using:
  - `ProxyCommand='tailscale nc %h %p'`
- over that recovery path we verified:
  - `sshd` was active
  - `sshd` was listening on `0.0.0.0:22`
  - `tailscale.service` was active
  - Grafana, Prometheus, Alertmanager, Homepage, and Promtail were active

That proved:

- the host was alive
- SSH itself was healthy
- the failure was specific to the normal LAN path

## Root Cause

### The real cause

`rpi-box-02` was still running an older live Tailscale container configuration:

```text
TS_EXTRA_ARGS=--advertise-routes=192.168.1.0/24 --accept-routes=true --accept-dns=false
```

This produced:

- `192.168.1.0/24 dev tailscale0 table 52`

At the same time, NixOS firewall reverse-path filtering was active on
`rpi-box-02`:

- `mangle` `PREROUTING`
- chain `nixos-fw-rpfilter`

Normal LAN packets arriving on `end0` from peers such as `meganix` then failed
reverse-path validation because the host believed the reverse route for
`192.168.1.0/24` belonged to `tailscale0`, not `end0`.

Those packets were dropped before they ever hit the normal `INPUT` rules for:

- ICMP echo
- TCP port `22`

### Strong proof captured during the session

These were the decisive findings:

1. `rpi-box-02` had:

```text
192.168.1.0/24 dev tailscale0 table 52
```

2. On `rpi-box-02`, `iptables -vnL nixos-fw` showed `0` packets for:

- `tcp dpt:22`
- `icmp type 8`

3. On `rpi-box-02`, while a fresh failed ping from `meganix` was running,
   `iptables -t mangle -vnL nixos-fw-rpfilter` showed the `DROP` counter
   increase.

That was the key proof:

- the packets were reaching the host early enough to hit rpfilter
- rpfilter was killing them before normal firewall rules or `sshd`

### Why `rpi-box-01` kept working

Comparison with `rpi-box-01` showed:

- same rpfilter chain existed there
- but `rpi-box-01` did **not** have `192.168.1.0/24 dev tailscale0 table 52`

So the breakage was not “rpfilter is bad in general”.

It was:

- `rpfilter`
- plus
- the wrong live Tailscale route advertisement/acceptance state on `rpi-box-02`

## What Was Changed To Fix It

### 1. `meganix` hardening in `~/nix`

File:

- `/home/eduardo/nix/hosts/meganix/configuration.nix`

Permanent sysctls now present:

- `net.ipv4.conf.all.arp_ignore = 1`
- `net.ipv4.conf.all.arp_announce = 2`
- `net.ipv4.conf.default.arp_ignore = 1`
- `net.ipv4.conf.default.arp_announce = 2`
- `net.ipv4.conf.all.arp_filter = 1`
- `net.ipv4.conf.default.arp_filter = 1`

This did matter:

- it cleaned up earlier ARP ambiguity caused by `meganix` having three NICs on
  `192.168.1.0/24`

But it was **not** sufficient by itself to restore `rpi-box-02`.

Keep it anyway.

### 2. `nix-pi-private` was brought up to date with newer public `nix-pi` Tailscale intent

The later public `nix-pi` history had evolved after the original companion
migration work:

- `rpi-box-01` gained `tailscale-reconcile`
- `rpi-box-02` and `rpi-box-03` gained/simplified Tailscale node behavior

Those changes had collided with the public migration rebase because they still
existed in the old tracked public private files.

To preserve that intent properly, `nix-pi-private` was updated so it now
contains the effective current Tailscale design:

- `rpi-box-01`
  - keeps LAN route advertisement
  - keeps `acceptRoutes = true`
  - now includes `tailscale-reconcile`
- `rpi-box-02`
  - no longer advertises `192.168.1.0/24`
  - now uses `acceptRoutes = false`
  - no longer sets `firewallMode = "nftables"`
  - now includes `tailscale-reconcile`
- `rpi-box-03`
  - now imports tailscale again
  - now declares `tailscale-authkey`
  - now includes `services.tailscaleCompose`
  - now includes `tailscale-reconcile`

### 3. Targeted redeploy of `rpi-box-02`

This was the fix that restored normal LAN access.

It was run using the Tailscale recovery path only as transport, with:

- public flake:
  - `nix-pi`
- private override:
  - local `nix-pi-private`
- `nix-services` override:
  - local `nix-services`

Result after redeploy:

- live Tailscale container env on `rpi-box-02` became:

```text
TS_EXTRA_ARGS=--accept-routes=false --accept-dns=false
```

and importantly no longer included:

- `--advertise-routes=192.168.1.0/24`

After that:

- `ping 192.168.1.59` from `meganix` succeeded
- `ssh eduardo@rpi-box-02` from `meganix` succeeded
- `ping 192.168.1.59` from `rpi-box-01` succeeded

## Exact Commands Worth Reusing

### Recovery SSH transport to `rpi-box-02`

```bash
ssh \
  -o ProxyCommand='tailscale nc %h %p' \
  -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile=/home/eduardo/.ssh/known_hosts \
  -o IdentitiesOnly=yes \
  -i /home/eduardo/.ssh/meganix_ed25519 \
  eduardo@rpi-box-02.tail9ced83.ts.net
```

### Validation

```bash
export NIX_PI_PRIVATE_FLAKE=/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi-private
export NIX_PI_NIX_SERVICES_FLAKE=/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-services

nix run "path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi#validate-private-config" -- rpi-box-02
nix run "path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi#validate-pi-host" -- rpi-box-02
```

Both passed with the corrected local `nix-pi-private`.

### Targeted redeploy that fixed the outage

```bash
export NIX_PI_PRIVATE_FLAKE=/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi-private
export NIX_SSHOPTS='-o ProxyCommand=tailscale\ nc\ %h\ %p -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/home/eduardo/.ssh/known_hosts -o IdentitiesOnly=yes -i /home/eduardo/.ssh/meganix_ed25519'

nixos-rebuild switch \
  --flake path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi#rpi-box-02 \
  --override-input nix-services path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-services \
  --override-input private path:/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi-private \
  --target-host eduardo@rpi-box-02.tail9ced83.ts.net \
  --build-host eduardo@rpi-box-02.tail9ced83.ts.net \
  --sudo
```

## Git / Repo Status At End Of Session

### `nix`

Path:

- `/home/eduardo/nix`

Important commits:

- `a11559e` `arp problems in the network`
- `c8c8bba` `Harden meganix ARP filtering`

Push status:

- should be pushed at session end if not already

### `nix-pi`

Path:

- `/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi`

Important commit:

- `6e36f4c` `Migrate nix-pi to private companion flake`

Important note:

- this commit was rebased on top of newer upstream public `nix-pi` history
- the rebase conflict came from later Tailscale changes in old tracked private
  files
- those changes were intentionally preserved by porting their effective intent
  into `nix-pi-private`

Push status:

- pushed to `origin/main` during this session

### `nix-pi-private`

Path:

- `/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-pi-private`

Important commits:

- `13f7400` `Create nix-pi private companion flake`
- `9b09132` `Restore rpi-box-02 tailscale config`
- `66d99ae` `Align private tailscale config with latest nix-pi changes`

Remote added during this session:

- `origin`
- `ssh://git@gitea.<homelab-domain>:2222/eduardo/nix-pi-private.git`

Push status:

- should be pushed at session end if not already

### `nix-cluster`

Path:

- `/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-cluster`

Important warning:

- this repo already had pre-existing local docs changes before this handoff file
  was added
- do **not** casually reset or clean it
- commit only intentional files

At the time this handoff was written, docs-related local state included:

- modified:
  - `docs/NEXT_SESSION_HANDOFF_2026-03-21_HOMELAB_PRIVATE_COMPANION_REPO_MIGRATION.md`
  - `docs/PRIVATE_COMPANION_REPO_CONVENTION.md`
- untracked:
  - `docs/HOMELAB_OPERATOR_BOOTSTRAP_RUNBOOK.md`
  - `docs/HOMELAB_PRIVATE_COMPANION_REPO_INVENTORY_AND_MIGRATION_PLAN.md`
  - `docs/NEXT_SESSION_HANDOFF_2026-03-21_NIX_PI_PRIVATE_COMPANION_MIGRATION_AND_ROLLOUT.md`

Treat those as intentional existing work unless explicitly told otherwise.

### `nix-cluster-private`

Path:

- `/home/eduardo/Programming/gitea.<homelab-domain>/hhlab-insfrastructure/nix-cluster-private`

Important note:

- at the time of this session, this path existed but was **not** a git repo yet

### Private remotes created in Gitea

User stated these Gitea repos now exist:

- `nix-pi-private`
- `nix-cluster-private`
- `nix-services-private`
- `synology-services-private`

Only `nix-pi-private` was wired locally during this session.

## What To Verify First In The Next Fresh Session

1. Confirm `rpi-box-02` still works on the normal LAN path:
   - `ping 192.168.1.59`
   - `ssh eduardo@rpi-box-02 hostname`
2. Confirm live Tailscale env on `rpi-box-02` still shows:
   - `TS_EXTRA_ARGS=--accept-routes=false --accept-dns=false`
3. Confirm `nix-pi-private` was pushed to its new remote
4. Confirm `~/nix` was pushed after `c8c8bba`
5. Then resume the broader private companion migration work for:
   - `nix-services`
   - later `nix-cluster-private` and `synology-services-private`

## Recommended Next Session Start Order

Read in this order:

1. this handoff
2. `nix-cluster/docs/NEXT_SESSION_HANDOFF_2026-03-21_NIX_PI_PRIVATE_COMPANION_MIGRATION_AND_ROLLOUT.md`
3. `nix-cluster/docs/HOMELAB_PRIVATE_COMPANION_REPO_INVENTORY_AND_MIGRATION_PLAN.md`
4. `nix-cluster/docs/HOMELAB_OPERATOR_BOOTSTRAP_RUNBOOK.md`
5. `nix-pi/README.md`
6. `nix-pi/AGENTS.md`
7. `nix-pi-private/README.md`

Then do this:

1. Verify final push state for:
   - `nix`
   - `nix-pi-private`
2. Verify `rpi-box-02` still has normal LAN SSH
3. If stable, start the same explicit companion pattern for `nix-services`
4. When ready, initialize and wire:
   - `nix-cluster-private`
   - `nix-services-private`
   - `synology-services-private`

## Key Lessons To Preserve

### 1. Public/private split still stands

Do not regress from:

- public repo with placeholder private input
- real sibling private repo with real environment-specific modules
- explicit public repo root passed into private modules via `piRepoRoot`

### 2. Runtime drift can outlive config edits

Even after the public/private migration looked “done”, `rpi-box-02` was still
running an older Tailscale runtime shape.

So when behavior is weird:

- inspect the live container env
- inspect policy routing
- inspect rpfilter counters

Do not assume the current local Nix files match live runtime.

### 3. Tailscale subnet routes can interact badly with rpfilter

If a host advertises or accepts its own LAN in a way that inserts a route such
as:

- `192.168.1.0/24 dev tailscale0 table 52`

and NixOS reverse-path filtering is on, normal LAN packets can be dropped before
they reach normal firewall rules.

This exact failure happened here.

### 4. Recovery path should be distinct from the steady-state path

Tailscale SSH / `tailscale nc` was essential for recovery.

But it should remain:

- recovery transport

not:

- the assumed normal operating path for LAN hosts that should be reachable
  directly

Keep verifying normal LAN access explicitly after any network- or
Tailscale-related redeploy.
