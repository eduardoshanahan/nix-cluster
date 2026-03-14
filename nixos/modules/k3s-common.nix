{ config, lib, ... }:
let
  isServer = config.homelab.cluster.nodeRole == "server";
  isBootstrapServer = config.networking.hostName == "cluster-pi-01";
in
lib.mkMerge [
  {
    assertions = [
      {
        assertion = config.homelab.adminAuthorizedKeys != [ ];
        message = "Set homelab.adminAuthorizedKeys in private overrides before building node images.";
      }
      {
        assertion = config.homelab.cluster.clusterToken != null;
        message = "Set homelab.cluster.clusterToken in private overrides before deploying the cluster.";
      }
    ];

    services.k3s = {
      enable = true;
      role = config.homelab.cluster.nodeRole;
      token = config.homelab.cluster.clusterToken;
      extraFlags = [
        "--write-kubeconfig-mode=0644"
        "--cluster-cidr=${config.homelab.cluster.clusterCidr}"
        "--service-cidr=${config.homelab.cluster.serviceCidr}"
        "--disable=servicelb"
        "--disable=traefik"
      ] ++ lib.optionals isServer (
        map (san: "--tls-san=${san}") config.homelab.cluster.tlsSan
      );
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts =
        [
          22
          10250
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

  (lib.mkIf isBootstrapServer {
    services.k3s.clusterInit = true;
  })

  (lib.mkIf (!isBootstrapServer) {
    services.k3s.serverAddr = config.homelab.cluster.apiServerEndpoint;
  })
]
