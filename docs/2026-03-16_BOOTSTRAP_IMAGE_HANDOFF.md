# 2026-03-16 Bootstrap Image Handoff

## Purpose

This document captures the exact state of the fresh-start cluster work at the
end of the March 16, 2026 session so a new session can resume cleanly.

The main outcome of this session is:

- the shared bootstrap SD image was successfully built on `rpi-box-01`
- the remote builder host was cleaned first
- the repository was adjusted so the bootstrap image is truly generic
- flashing has not happened yet

## What Changed In The Repository

The repository was updated to match the documented restart plan more closely.

Key changes:

- the shared bootstrap image is no longer a pre-baked `k3s agent`
- `homelab.cluster.enable` was introduced so the generic bootstrap image can
  boot with SSH and base OS settings but without starting `k3s`
- `homelab.cluster.nodeRole` can now be `null` for the bootstrap-only image
- validation logic was updated so it still strictly checks real cluster nodes
  while allowing the bootstrap image to remain generic
- the flake now exposes a host-buildable `bootstrap-sd-image` package

Relevant files:

- `flake.nix`
- `nixos/modules/options.nix`
- `nixos/modules/k3s-common.nix`
- `nixos/modules/validation.nix`

## Important Build Lesson From This Session

The local workstation could not build the SD image directly because it only had
`x86_64-linux` builders available, while the SD image derivation needed
`aarch64-linux`.

That means:

- image builds should be done on `rpi-box-01`
- or another host that can natively build `aarch64-linux`

This was not recorded in the previous docs, but it should now be treated as the
current operational reality.

## Remote Build Host

- host: `rpi-box-01`
- remote workspace used for this session: `~/nix-cluster`

There was no existing checkout there at the start of the session, so the
current repository contents were copied to that path before building.

## Cleanup Performed On `rpi-box-01`

Before rebuilding, `rpi-box-01` was cleaned with Nix garbage collection.

Observed results:

- before cleanup: about `7.9G` free on `/`
- after cleanup: about `23G` free on `/`
- approximately `14.66 GiB` was reclaimed

This removed stale unrooted cluster image artifacts left from previous builds.

## Build Command Used

The build was started on `rpi-box-01` from `~/nix-cluster` with:

```bash
nix build .#bootstrap-sd-image --print-out-paths
```

## Build Result

The build completed successfully.

Result symlink:

```text
~/nix-cluster/result
```

Resolved output directory:

```text
/nix/store/wf7mhkdn2x2h5ci4mj4nry2wf7fjmf9k-nixos-image-sd-card-26.05.20260313.c06b4ae-aarch64-linux.img.zst
```

Actual SD image payload:

```text
/nix/store/wf7mhkdn2x2h5ci4mj4nry2wf7fjmf9k-nixos-image-sd-card-26.05.20260313.c06b4ae-aarch64-linux.img.zst/sd-image/nixos-image-sd-card-26.05.20260313.c06b4ae-aarch64-linux.img.zst
```

Build metadata checks confirmed:

- product type: `sd-image`
- target system: `aarch64-linux`

Image size observed:

- compressed: about `1.28 GiB`
- decompressed: about `3.11 GiB`

## Inspection Status

Artifact-level inspection is complete:

- the `result` symlink exists
- it resolves to the expected Nix SD image output directory
- the `sd-image/` payload exists
- metadata matches a real `aarch64-linux` Raspberry Pi SD image build

Deeper filesystem inspection was started but not fully completed before the
session ended.

The unfinished inspection was intended to:

- decompress the image to `/tmp/cluster-bootstrap-inspect.img` on
  `rpi-box-01`
- inspect the partition table with `fdisk`
- mount the root filesystem read-only
- verify `/etc/hostname`
- verify `/etc/ssh/authorized_keys/eduardo`

At the time of stopping, the decompression/mount check was still running on
`rpi-box-01` and had not yet produced the final `/etc` verification output.

Because the image build itself succeeded and the output structure is correct,
the project is in a good state to resume from here.

## Current Bootstrap Intent

The shared bootstrap image is meant to be generic.

Expected properties:

- generic bootstrap hostname rather than a final node identity
- SSH access available through the embedded authorized keys
- Raspberry Pi 4 SD boot image layout
- no cluster-specific `k3s` role started directly in the bootstrap image

Per-node cluster behavior should still be applied later through the
node-specific configs such as:

- `cluster-pi-01`
- `cluster-pi-02`
- `cluster-pi-03`
- `cluster-pi-04`
- `cluster-pi-05`

## Recommended Next Session

1. Reconnect to `rpi-box-01`.
2. Check whether the read-only inspection process is still running.
3. If needed, rerun a focused read-only inspection of the built image and
   confirm:
   - partition layout looks correct
   - `/etc/hostname` contains the expected bootstrap hostname
   - `/etc/ssh/authorized_keys/eduardo` contains the expected keys
4. Once inspection is satisfactory, flash the image to the SD card for
   `cluster-pi-01`.
5. Boot only `cluster-pi-01`.
6. Verify SSH access and basic bootstrap behavior.
7. Apply the node-specific post-boot configuration flow for `cluster-pi-01`.

## Suggested Flashing Source

When ready to flash later, use the built artifact from:

```text
~/nix-cluster/result
```

or directly from:

```text
/nix/store/wf7mhkdn2x2h5ci4mj4nry2wf7fjmf9k-nixos-image-sd-card-26.05.20260313.c06b4ae-aarch64-linux.img.zst/sd-image/nixos-image-sd-card-26.05.20260313.c06b4ae-aarch64-linux.img.zst
```

## Operator Notes

- `rpi-box-01` is now the important build host to remember
- the missing piece from previous documentation was where the image builds were
  actually performed
- this session corrected that gap
- no flashing was performed yet
- no sibling repositories were edited
