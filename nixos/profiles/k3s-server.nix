{ lib, ... }:
{
  homelab.cluster.nodeRole = lib.mkDefault "server";
}
