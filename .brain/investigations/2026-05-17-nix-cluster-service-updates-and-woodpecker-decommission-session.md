# Task: 2026-05-17 nix-cluster service updates and Woodpecker decommission session

## Status
raw

## Source Repo
nix-cluster (+ nix, nix-pi-private, synology-services)

## Context
kubernetes, homelab

## What was attempted

### Woodpecker CI decommission
- Removed Woodpecker OCI container from meganix (nix/hosts/meganix/virtualisation.nix)
- Added Gitea Actions runner to meganix via services.gitea-actions-runner NixOS module
- Replaced woodpecker-agent-secret.age with gitea-runner-token.age in nix/secrets/
- Rebuilt meganix — runner is active and registered in Gitea UI
- Removed woodpecker from rpi-box-02 config (nix-pi-private/modules/rpi-box-02.nix)
- Rebuilt rpi-box-02 with nixos-rebuild switch (removes all OCI woodpecker units)
- Removed woodpecker-agent from hhnas4 managed stacks list (start-managed-stacks.sh)
- Deployed updated start-managed-stacks.sh to hhnas4 via deploy-start-managed-stacks.sh

### nix-cluster version bumps (all applied to cluster)
- wikijs: 2.5.300 → 2.5.314
- schema-registry (confluentinc/cp-schema-registry): 7.9.2 → 7.9.7
- kube-state-metrics Helm chart: 7.2.2 → 7.3.0
- headlamp Helm chart: 0.41.0 → 0.42.0
- spark (history-server, Dockerfile, Dockerfile.jupyter): apache/spark:3.5.3 → 3.5.8
- spark-jupyter deployment: spark-jupyter:3.5.3 → 3.5.8
- build-and-deploy.sh: IMAGE_TAG 3.5.3 → 3.5.8

### kubeconfig refresh
- k3s CA was regenerated on the cluster (CA timestamp mismatch: @1773698765 vs @1776793626)
- Fetched new kubeconfig from cluster-pi-01:/etc/rancher/k3s/k3s.yaml via SSH
- Updated local ~/.kube/config with new CA cert and server URL

### spark image build + deploy
- Built spark-s3:3.5.8 and spark-jupyter:3.5.8 via docker buildx (linux/arm64)
- Imported both images to all 5 cluster nodes via SSH + k3s ctr images import
- Note: build-and-deploy.sh uses placeholder hostnames (cluster-node-NN.internal.example)
  → must import manually using real hostnames (cluster-pi-NN.<homelab-domain>)

## What worked

- Gitea Actions runner module `services.gitea-actions-runner.instances."<name>"` works cleanly
- tokenFile format: must be `TOKEN=<value>` (env-file format) not bare token
- spark image import to k3s: `ssh node "sudo k3s ctr images import -" < image.tar`
- render-platform / render-headlamp / render-spark / render-wikijs / render-kafka all work
- Fetching fresh kubeconfig from k3s node via SSH when local kubeconfig has stale CA cert

## What failed

- build-and-deploy.sh uses hardcoded placeholder hostnames — SSH deploy step fails
  → workaround: save images to tar, import manually with real hostnames
- First gitea-runner-token encrypted as bare token — NixOS EnvironmentFile requires KEY=VALUE format
  → re-encrypted with TOKEN=<value> prefix

## Wrong assumptions

- Assumed local kubeconfig CA cert was still valid — k3s CA had been regenerated
- Assumed build-and-deploy.sh would work end-to-end — deploy section uses placeholder hostnames

## Reusable insights

- When kubectl returns "certificate signed by unknown authority": k3s CA may have been regenerated.
  Fix: `ssh cluster-pi-01 "sudo cat /etc/rancher/k3s/k3s.yaml" | sed 's|127.0.0.1:6443|cluster-api.<homelab-domain>:6443|' > ~/.kube/config`
- build-and-deploy.sh IMAGE_TAG must be updated alongside Dockerfile/deployment.yaml version bumps
- spark-jupyter image is a local-only image (not in a registry) — must be built and imported to every node before the deployment can start

## Candidate for promotion
kubeconfig refresh procedure → runbook
