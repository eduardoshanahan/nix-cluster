# SD Card And Bootstrap Runbook

## Purpose

This runbook describes the first-pass process for preparing SD cards and
bringing up the Raspberry Pi Kubernetes cluster.

It is intentionally focused on the first platform bootstrap, not on workload
migration.

## Preconditions

Before flashing SD cards, we should have:

- final node naming
- DHCP reservations created on the UCG Max for all five nodes
- SSH public keys for administration
- a private cluster token
- private host override files in `nixos/hosts/private/`

The intended access model is SSH-key-first:

- admin public keys are baked into the SD-card image
- SSH password authentication stays disabled
- no bootstrap passwords need to be passed around

## Expected Bootstrap Order

1. Build the Raspberry Pi 4 image from this repository.
2. Write the image to five SD cards.
3. Confirm each Pi MAC address is mapped to the intended DHCP reservation.
4. Boot `cluster-pi-01` first.
5. Verify SSH access and `k3s` server health on `cluster-pi-01`.
6. Boot `cluster-pi-02` and `cluster-pi-03`.
7. Verify control-plane quorum and node readiness.
8. Boot `cluster-pi-04` and `cluster-pi-05`.
9. Verify worker registration and cluster health.

## Image Strategy

The repository scaffold provides:

- one generic Raspberry Pi 4 profile suitable for cluster nodes
- host-specific configurations for each planned node

If we want a fully zero-touch flow, we will eventually prefer host-specific
images or a first-boot mechanism that sets host identity declaratively.

## DHCP Reservation Plan

The preferred network model is:

- DHCP served by the UCG Max
- one reservation per Raspberry Pi
- DNS or local naming aligned with the reserved addresses

This keeps addresses stable without hardcoding gateway and subnet data into the
node configs.

## First Verification Checklist

After each node boots:

- it receives the expected hostname
- it reaches the LAN
- SSH access works with the expected admin key and does not require a password
- `k3s` starts without repeated crash loops

After the first control-plane node boots:

- `systemctl status k3s`
- `kubectl get nodes`
- `kubectl get pods -A`

After all five nodes boot:

- all nodes appear in `Ready` state
- control-plane nodes remain healthy after a reboot test
- worker nodes remain attached after a reboot test

## Integration Notes

Once the base cluster is stable, the next bootstrap-adjacent tasks are likely:

- add Uptime Kuma monitors for the API endpoint and key services
- decide how cluster ingress should consume the homelab certificate model
- decide which external services should be reused before deploying cluster apps
