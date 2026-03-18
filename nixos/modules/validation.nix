{ config, lib, ... }:
let
  clusterEnabled = config.homelab.cluster.enable;
  role = config.homelab.cluster.nodeRole;
  isServer = role == "server";
  flags = if clusterEnabled then config.services.k3s.extraFlags else [ ];
  execStart = if clusterEnabled then config.systemd.services.k3s.serviceConfig.ExecStart else "";
  hasWriteKubeconfigMode = builtins.any (flag: lib.hasInfix "--write-kubeconfig-mode" flag) flags;
  hasClusterCidr = builtins.any (flag: lib.hasInfix "--cluster-cidr" flag) flags;
  hasServiceCidr = builtins.any (flag: lib.hasInfix "--service-cidr" flag) flags;
  hasDisableServiceLb = builtins.any (flag: lib.hasInfix "--disable=servicelb" flag) flags;
  hasDisableTraefik = builtins.any (flag: lib.hasInfix "--disable=traefik" flag) flags;
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
      assertion = (!(clusterEnabled && isServer)) || hasClusterCidr;
      message = "Control-plane nodes must include --cluster-cidr in their k3s flags.";
    }
    {
      assertion = (!(clusterEnabled && isServer)) || hasDisableServiceLb;
      message = "Control-plane nodes must disable servicelb in their k3s flags.";
    }
    {
      assertion = (!(clusterEnabled && isServer)) || hasDisableTraefik;
      message = "Control-plane nodes must disable traefik in their k3s flags.";
    }
    {
      assertion = (!(clusterEnabled && isServer)) || hasServiceCidr;
      message = "Control-plane nodes must include --service-cidr in their k3s flags.";
    }
    {
      assertion = (!(clusterEnabled && (!isServer))) || (!hasWriteKubeconfigMode);
      message = "Worker nodes must not include --write-kubeconfig-mode in their k3s flags.";
    }
    {
      assertion = (!(clusterEnabled && (!isServer))) || (!hasClusterCidr);
      message = "Worker nodes must not include --cluster-cidr in their k3s flags.";
    }
    {
      assertion = (!(clusterEnabled && (!isServer))) || (!hasDisableServiceLb);
      message = "Worker nodes must not include --disable=servicelb in their k3s flags.";
    }
    {
      assertion = (!(clusterEnabled && (!isServer))) || (!hasDisableTraefik);
      message = "Worker nodes must not include --disable=traefik in their k3s flags.";
    }
    {
      assertion = (!(clusterEnabled && (!isServer))) || (!hasServiceCidr);
      message = "Worker nodes must not include --service-cidr in their k3s flags.";
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
