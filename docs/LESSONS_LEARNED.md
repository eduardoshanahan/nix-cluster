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

We hit a worker-node failure caused by a server-only flag being passed to
`k3s agent`:

- `--write-kubeconfig-mode=0644`

That led to repeated worker startup failure and showed that the workflow needed
stronger validation and cleaner artifact handling.

## Operational Lessons

### Keep image roles simple

Base hardware bootstrap, cluster role, and node identity should be treated as
separate layers.

### Validate generated output

Generated `k3s.service` content is a first-class artifact and should be checked
before flashing.

### Prefer deploys after bootstrap

Once a node boots and SSH works, we should strongly prefer a Nix deploy path
instead of falling back to full SD-card rebuilds for normal iteration.

### Use fresh build outputs when debugging

Fresh output names and direct artifact inspection are safer than trusting a
previous symlink blindly.

### Keep the learning loop explicit

Because this cluster is also a learning project, the repository should explain
not only what we are doing, but why the workflow is shaped this way.

## Working Rule That Still Applies

We may read from sibling repositories for context while working here.

We must not edit them without explicit authorization.
