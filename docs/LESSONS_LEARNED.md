# Lessons Learned

## Why We Are Restarting

The first implementation pass got part of the cluster working, but it exposed a
workflow problem.

The cluster design was mostly reasonable. The provisioning and recovery process
was not robust enough.

## What Worked

- `k3s` is still a sensible choice for this hardware
- NixOS remains the right operating-system direction
- three control-plane nodes and two workers is still the intended topology
- DHCP reservations and stable DNS names are good choices
- SSH-key-only bootstrap is the right access model
- integrating with the existing homelab remains the right long-term goal

## What Failed

The weak point was the image workflow.

Problems we observed:

- too much confidence in host-specific SD-card images
- too little validation before flashing
- too much reliance on reflashing to recover from mistakes
- not enough separation between server-only and worker-only `k3s` behavior
- stale artifacts were too easy to confuse with fresh ones

## Concrete Failure We Hit

We hit a worker-node failure caused by server-only flags being passed to
`k3s agent`:

- `--write-kubeconfig-mode=0644`
- `--cluster-cidr=...`
- `--service-cidr=...`
- `--disable=servicelb`
- `--disable=traefik`

That led to repeated worker startup failure and showed that the workflow needed
stronger validation and cleaner artifact handling.

## Operational Lessons

### Keep the bootstrap image generic

Base hardware bootstrap, node role, and node identity should be treated as
separate layers.

For the restart, we are choosing the strictest version of that rule:

- one shared bootstrap image
- configuration after first boot

### Validate generated output

Generated `k3s.service` content is a first-class artifact and should be checked
before flashing.

### Prefer deploys after bootstrap

Once a node boots and SSH works, we should strongly prefer a Nix deploy path
instead of falling back to full SD-card rebuilds for normal iteration.

### A remote builder must be a signed builder

Today we proved a narrower but very important version of the deploy lesson:

- `--build-host` is not enough by itself
- if the builder does not sign locally built outputs, targets with
  `require-sigs = true` will reject those store paths
- if the target does not trust the builder public key, the deploy still fails

So the real long-term rule is:

- use a remote ARM builder
- give that builder a stable signing identity
- make cluster targets trust that builder key

Without those three pieces together, the "fast post-boot deploy" story is only
partially implemented.

### Flashed nodes may carry stale `k3s` state

Today we also learned that a flashed node can switch declaratively to a new
hostname and role while still keeping enough on-disk `k3s` state to behave like
the old node identity.

Observed symptoms:

- `/etc/hostname` changed
- runtime hostname lagged until reboot
- even after reboot, `k3s` could still act like an old embedded cluster member
- wiping `/var/lib/rancher/k3s` was needed to get a clean join

That means first-boot post-image conversion needs an explicit stale-state check
or cleanup step in the runbook.

### Worker joins can also fail on stale node passwords

The March 18 rollout added a second worker-specific stale-state discovery:

- a worker can keep a stale `/etc/rancher/node/password`
- after hostname conversion, the agent may be rejected for duplicate hostname
  or mismatched node password

That means worker recovery can require cleaning two locations together:

- `/var/lib/rancher/k3s`
- `/etc/rancher/node/password`

if reboot alone does not let the worker rejoin cleanly.

### Use fresh build outputs when debugging

Fresh output names and direct artifact inspection are safer than trusting a
previous symlink blindly.

### Keep the learning loop explicit

Because this cluster is also a learning project, the repository should explain
not only what we are doing, but why the workflow is shaped this way.

## Working Rule That Still Applies

We may read from sibling repositories for context while working here.

We must not edit them without explicit authorization.
