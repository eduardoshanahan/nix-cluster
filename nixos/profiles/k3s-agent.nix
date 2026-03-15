{ lib, ... }:
{
  homelab.cluster.nodeRole = lib.mkDefault "agent";
}
