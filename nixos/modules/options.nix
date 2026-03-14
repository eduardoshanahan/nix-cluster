{ lib, ... }:
{
  options = {
    homelab = {
      adminUser = lib.mkOption {
        type = lib.types.str;
        default = "eduardo";
        description = "Administrative user created on cluster nodes.";
      };

      adminAuthorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "SSH public keys written into the image at /etc/ssh/authorized_keys/<adminUser>.";
      };

      timezone = lib.mkOption {
        type = lib.types.str;
        default = "Europe/Dublin";
        description = "Default node timezone.";
      };

      domain = lib.mkOption {
        type = lib.types.str;
        default = "cluster.internal.example";
        description = "Default domain placeholder overridden in private config.";
      };

      cluster = {
        name = lib.mkOption {
          type = lib.types.str;
          default = "homelab-k3s";
          description = "Human-readable cluster name.";
        };

        nodeRole = lib.mkOption {
          type = lib.types.enum [ "server" "agent" ];
          description = "Whether this node acts as a k3s server or agent.";
        };

        apiServerEndpoint = lib.mkOption {
          type = lib.types.str;
          default = "https://cluster-api.internal.example:6443";
          description = "Stable Kubernetes API endpoint used by joining nodes.";
        };

        clusterToken = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Bootstrap cluster token. Keep this in private host overrides.";
        };

        serviceCidr = lib.mkOption {
          type = lib.types.str;
          default = "10.43.0.0/16";
          description = "k3s service CIDR.";
        };

        clusterCidr = lib.mkOption {
          type = lib.types.str;
          default = "10.42.0.0/16";
          description = "k3s pod CIDR.";
        };

        tlsSan = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional TLS SAN values for the Kubernetes API server.";
        };
      };
    };
  };
}
