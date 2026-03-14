# Private Host Overrides

Place environment-specific and sensitive overrides here.

This directory is for local use only and should not be committed.

## What belongs here

- SSH authorized keys
- node IP addressing choices if they are environment-specific
- cluster bootstrap token
- real homelab domain values
- future certificate paths or other secret-adjacent local configuration

## Expected files

- `overrides.nix`
- `cluster-pi-01.nix`
- `cluster-pi-02.nix`
- `cluster-pi-03.nix`
- `cluster-pi-04.nix`
- `cluster-pi-05.nix`

Use `overrides.nix` for shared settings that apply to all cluster nodes, such as
the admin SSH keys, the homelab domain, and the shared cluster bootstrap token.

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
}
```

This follows the same pattern used in `nix-pi`: the public SSH key is embedded
into the image so the node is reachable immediately after first boot without
sharing bootstrap passwords.
