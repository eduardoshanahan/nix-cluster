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
      "--disable-network-policy"
      "--flannel-backend=none"
      "--disable-kube-proxy"
      "--cluster-cidr=${config.homelab.cluster.clusterCidr}"
      "--service-cidr=${config.homelab.cluster.serviceCidr}"
      "--write-kubeconfig-mode=0644"
      # Expose scheduler and controller-manager metrics on all interfaces
      # so the in-cluster control-plane metrics proxy can scrape them.
      "--kube-scheduler-arg=bind-address=0.0.0.0"
      "--kube-scheduler-arg=authorization-always-allow-paths=/metrics,/healthz,/readyz"
      "--kube-controller-manager-arg=bind-address=0.0.0.0"
      "--kube-controller-manager-arg=authorization-always-allow-paths=/metrics,/healthz,/readyz"
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
            80
            443
            4240 # cilium-health inter-node health checks
            10250 # kubelet API — required by metrics-server to scrape node resource usage
            config.homelab.observability.nodeExporter.port
          ]
          ++ lib.optionals isServer [
            6443
            9345
            2379
            2380
            10257 # kube-controller-manager metrics
            10259 # kube-scheduler metrics
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
