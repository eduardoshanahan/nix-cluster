{ config, lib, ... }:
let
  clusterEnabled = config.homelab.cluster.enable;
  role = config.homelab.cluster.nodeRole;
  isServer = role == "server";
  flags = if clusterEnabled then config.services.k3s.extraFlags else [ ];
  execStart = if clusterEnabled then config.systemd.services.k3s.serviceConfig.ExecStart else "";
  hasWriteKubeconfigMode = builtins.any (flag: lib.hasInfix "--write-kubeconfig-mode" flag) flags;
in
{
  assertions = [
    {
      assertion = (!clusterEnabled) || role != null;
      message = "Set homelab.cluster.nodeRole when homelab.cluster.enable is true.";
    }
    {
      assertion = config.homelab.adminAuthorizedKeys != [ ];
      message = "Set homelab.adminAuthorizedKeys in private overrides before building node images.";
    }
    {
      assertion = (!clusterEnabled) || config.homelab.cluster.clusterToken != null;
      message = "Set homelab.cluster.clusterToken in private overrides before deploying the cluster.";
    }
    {
      assertion = (!(clusterEnabled && isServer)) || hasWriteKubeconfigMode;
      message = "Control-plane nodes must include --write-kubeconfig-mode in their k3s flags.";
    }
    {
      assertion = (!(clusterEnabled && (!isServer))) || (!hasWriteKubeconfigMode);
      message = "Worker nodes must not include --write-kubeconfig-mode in their k3s flags.";
    }
    {
      assertion = (!(clusterEnabled && isServer)) || (lib.hasInfix "/bin/k3s server" execStart);
      message = "Control-plane nodes must generate a k3s server ExecStart.";
    }
    {
      assertion = (!(clusterEnabled && (!isServer))) || (lib.hasInfix "/bin/k3s agent" execStart);
      message = "Worker nodes must generate a k3s agent ExecStart.";
    }
  ];
}
