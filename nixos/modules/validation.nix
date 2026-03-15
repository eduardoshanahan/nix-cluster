{ config, lib, ... }:
let
  role = config.homelab.cluster.nodeRole;
  isServer = role == "server";
  flags = config.services.k3s.extraFlags;
  execStart = config.systemd.services.k3s.serviceConfig.ExecStart;
  hasWriteKubeconfigMode = builtins.any (flag: lib.hasInfix "--write-kubeconfig-mode" flag) flags;
in
{
  assertions = [
    {
      assertion = config.services.k3s.enable;
      message = "The cluster layout assumes services.k3s is enabled on all nodes.";
    }
    {
      assertion = config.homelab.adminAuthorizedKeys != [ ];
      message = "Set homelab.adminAuthorizedKeys in private overrides before building node images.";
    }
    {
      assertion = config.homelab.cluster.clusterToken != null;
      message = "Set homelab.cluster.clusterToken in private overrides before deploying the cluster.";
    }
    {
      assertion = isServer -> hasWriteKubeconfigMode;
      message = "Control-plane nodes must include --write-kubeconfig-mode in their k3s flags.";
    }
    {
      assertion = (!isServer) -> (!hasWriteKubeconfigMode);
      message = "Worker nodes must not include --write-kubeconfig-mode in their k3s flags.";
    }
    {
      assertion = isServer -> lib.hasInfix "/bin/k3s server" execStart;
      message = "Control-plane nodes must generate a k3s server ExecStart.";
    }
    {
      assertion = (!isServer) -> lib.hasInfix "/bin/k3s agent" execStart;
      message = "Worker nodes must generate a k3s agent ExecStart.";
    }
  ];
}
