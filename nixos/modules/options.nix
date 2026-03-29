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

      privateConfig = {
        source = lib.mkOption {
          type = lib.types.str;
          default = "private-config-template";
          description = "Human-readable description of the active private config source.";
        };

        isPlaceholder = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether the active private config is still a placeholder template.";
        };
      };

      nix = {
        trustedBuilderPublicKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Nix signing public keys trusted by cluster nodes for cross-host
            store-path copies, such as a shared ARM builder.
          '';
        };
      };

      observability = {
        nodeExporter = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to expose Prometheus node_exporter on cluster nodes.";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 9100;
            description = "TCP port used by Prometheus node_exporter on cluster nodes.";
          };
        };
      };

      kubernetes = {
        ingressTlsSecretName = lib.mkOption {
          type = lib.types.str;
          default = "replace-with-private-tls-secret";
          description = "TLS secret name used by ingress resources rendered from this repo.";
        };

        metallb = {
          addressPool = lib.mkOption {
            type = lib.types.str;
            default = "198.51.100.10-198.51.100.20";
            description = "MetalLB address range for the shared LAN ingress IP pool.";
          };
        };
      };

      spark = {
        minioEndpoint = lib.mkOption {
          type = lib.types.str;
          default = "s3.internal.example";
          description = "MinIO S3 endpoint hostname for Spark event logs and data.";
        };

        minioBucket = lib.mkOption {
          type = lib.types.str;
          default = "spark-homelab";
          description = "MinIO S3 bucket name for Spark workloads.";
        };

        minioAccessKey = lib.mkOption {
          type = lib.types.str;
          default = "CHANGE_ME_ACCESS_KEY";
          description = "MinIO S3 access key for Spark (store in private config).";
        };

        minioSecretKey = lib.mkOption {
          type = lib.types.str;
          default = "CHANGE_ME_SECRET_KEY";
          description = "MinIO S3 secret key for Spark (store in private config).";
        };
      };

      cluster = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether this node should run k3s.";
        };

        name = lib.mkOption {
          type = lib.types.str;
          default = "homelab-k3s";
          description = "Human-readable cluster name.";
        };

        nodeRole = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "server"
              "agent"
            ]
          );
          default = null;
          description = "Whether this node acts as a k3s server or agent.";
        };

        bootstrapServer = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this server should run the initial cluster bootstrap.";
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
