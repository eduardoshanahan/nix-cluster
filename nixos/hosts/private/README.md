# Private Host Overrides

Place environment-specific and sensitive overrides here.

This directory is now legacy documentation and migration scaffolding.

Before validating or deploying cluster nodes, run:

```bash
nix run "path:$PWD#validate-private-config" -- cluster-pi-01
```

That helper checks both:

- that a real private flake exists locally
- that path-based flake evaluation resolves the required private values

The canonical private config location is now the sibling flake:

```bash
../nix-cluster-private
```

If you use a different location, export:

```bash
NIX_CLUSTER_PRIVATE_FLAKE=/absolute/path/to/nix-cluster-private
```

Use path-based flake refs for private config checks and node deploys:

```bash
path:$PWD#nixosConfigurations.cluster-pi-01
```

Do not rely on plain `.#...` references for this.

## What belongs here

- SSH authorized keys
- node IP addressing choices if they are environment-specific
- cluster bootstrap token
- trusted Nix builder public keys
- real homelab domain values
- future certificate paths or other secret-adjacent local configuration

## Legacy files

- `overrides.nix`
- `cluster-pi-01.nix`
- `cluster-pi-02.nix`
- `cluster-pi-03.nix`
- `cluster-pi-04.nix`
- `cluster-pi-05.nix`

These remain useful as examples of the module shape, but the preferred source
of truth is now the sibling private flake.

## Example

```nix
{ ... }:
{
  homelab.adminAuthorizedKeys = [
    "ssh-ed25519 AAAA... your-key"
  ];

  homelab.domain = "<homelab-domain>";

  homelab.cluster.apiServerEndpoint = "https://cluster-api.<homelab-domain>:6443";
  homelab.cluster.clusterToken = "replace-with-a-private-token";
  homelab.nix.trustedBuilderPublicKeys = [
    "rpi-box-01:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  ];
}
```

This follows the same pattern used in `nix-pi`: the public SSH key is embedded
into the image so the node is reachable immediately after first boot without
sharing bootstrap passwords.
