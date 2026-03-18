{ config, lib, ... }:
let
  isServer = config.homelab.cluster.nodeRole == "server";
  apiServerHostMatch = builtins.match "https://([^:/]+)(:[0-9]+)?(/.*)?" config.homelab.cluster.apiServerEndpoint;
  apiServerHost = if apiServerHostMatch == null then null else builtins.elemAt apiServerHostMatch 0;
  commonFlags = [ ];

  serverTlsSans = lib.unique (
    [ config.networking.hostName ]
    ++ lib.optionals (apiServerHost != null) [ apiServerHost ]
    ++ config.homelab.cluster.tlsSan
  );

  serverOnlyFlags =
    [
      "--disable=servicelb"
      "--disable=traefik"
      "--cluster-cidr=${config.homelab.cluster.clusterCidr}"
      "--service-cidr=${config.homelab.cluster.serviceCidr}"
      "--write-kubeconfig-mode=0644"
    ]
    ++ map (san: "--tls-san=${san}") serverTlsSans;
in
lib.mkIf config.homelab.cluster.enable (
  lib.mkMerge [
    {
      services.k3s = {
        enable = true;
        role = config.homelab.cluster.nodeRole;
        token = config.homelab.cluster.clusterToken;
        extraFlags = commonFlags ++ lib.optionals isServer serverOnlyFlags;
      };

      networking.firewall = {
        enable = true;
        allowedTCPPorts =
          [
            22
            10250
            30080
            30081
            config.homelab.observability.nodeExporter.port
          ]
          ++ lib.optionals isServer [
            6443
            9345
            2379
            2380
          ];
        allowedUDPPorts = [ 8472 ];
      };

      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
      };
    }

    (lib.mkIf config.homelab.cluster.bootstrapServer {
      services.k3s.clusterInit = true;
    })

    (lib.mkIf (!config.homelab.cluster.bootstrapServer) {
      services.k3s.serverAddr = config.homelab.cluster.apiServerEndpoint;
    })
  ]
)
